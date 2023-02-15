#!/usr/bin/env python
# --------------------------------------------------------------------------- #
#           ____  _____________  __                                           #
#          / __ \/ ____/ ___/\ \/ /                 _   _   _                 #
#         / / / / __/  \__ \  \  /                 / \ / \ / \                #
#        / /_/ / /___ ___/ /  / /               = ( M | S | K )=              #
#       /_____/_____//____/  /_/                   \_/ \_/ \_/                #
#                                                                             #
# --------------------------------------------------------------------------- #
# @copyright Copyright 2021-2022 DESY
# SPDX-License-Identifier: Apache-2.0
# --------------------------------------------------------------------------- #
# @date 2021-04-07/2023-02-15
# @author Michael Buechler <michael.buechler@desy.de>
# @author Lukasz Butkowski <lukasz.butkowski@desy.de>
# --------------------------------------------------------------------------- #
"""DesyRdl main class.

Create context dictionaries for each address space node.
Context dictionaries are used by the template engine.
"""

import re
from math import ceil, log2
from pathlib import Path
from systemrdl import AddressableNode, RDLListener
from systemrdl.node import (AddrmapNode, FieldNode,  # AddressableNode,
                            MemNode, RegfileNode, RegNode, RootNode)

from jinja2 import Template
import desyrdl

from desyrdl.rdlformatcode import desyrdlmarkup

# class convert dict to attributes of object
class AttributeDict(dict):
    __getattr__ = dict.get
    __setattr__ = dict.__setitem__
    __delattr__ = dict.__delitem__

# Define a listener that will print out the register model hierarchy
class DesyListener(RDLListener):

    def __init__(self):
        # def __init__(self, formatter, templates, out_dir, separator="."):
        self.separator = "."

        # global context
        self.top_items = list()
        self.top_regs = list()
        self.top_mems = list()
        self.top_exts = list()
        self.top_regf = list()
        self.top_context = dict()

        # local address map contect only
        self.items = list()
        self.regs = list()
        self.mems = list()
        self.exts = list()
        self.regf = list()
        self.context = dict()

        self.md = desyrdlmarkup() # parse description with markup lanugage, disable Mardown

    def exit_Addrmap(self, node : AddrmapNode):
        self.context.clear();
        self.context['items'] = list()
        self.context['regs']  = list()
        self.context['mems']  = list()
        self.context['exts']  = list()
        self.context['regf']  = list()

        self.context['node'] = node
        self.context['type_name'] = node.type_name
        self.context['inst_name'] = node.inst_name
        self.context['interface_type'] = node.get_property('desyrdl_interface')
        self.context['access_channel'] = self.get_access_channel(node)

        self.context['desc'] = node.get_property("desc")
        self.context['desc_html'] = node.get_html_desc(self.md)

        path_segments = node.get_path_segments(array_suffix=f'{self.separator}{{index:d}}', empty_array_suffix='')
        self.context['path_segments'] = path_segments
        self.context['path'] = self.separator.join(path_segments)
        self.context['path_notop'] = self.separator.join(path_segments[1:])
        self.context['path_addrmap_name'] = path_segments[-1]

        self.gen_items(node, self.context)

        self.top_items.append(self.context['items'])
        self.top_regs.append(self.context['regs'])
        self.top_mems.append(self.context['mems'])
        self.top_exts.append(self.context['exts'])
        self.top_regf.append(self.context['regf'])

    def gen_items (self, node , context):

        for item in node.children(unroll=False):
            itemContext = dict()
            # common to all items values
            itemContext['node'] = item
            itemContext['type_name'] = item.type_name
            itemContext['inst_name'] = item.inst_name
            itemContext['access_channel'] = self.get_access_channel(item)
            itemContext['address_offset'] = item.raw_address_offset
            itemContext['absolute_address'] = item.raw_address_offset
            itemContext['array_stride'] = item.array_stride if item.array_stride is not None else 0

            itemContext['desc'] = item.get_property("desc")
            itemContext['desc_html'] = item.get_html_desc(self.md)

            self.set_item_dimmentions(item, itemContext)

            # add all non-native explicitly set properties
            for prop in item.list_properties(list_all=True):
                itemContext[prop] = item.get_property(prop)

            # item specyfic context
            if isinstance(item, RegNode):
                itemContext['node_type'] = "REG"
                self.gen_regitem(item, context=itemContext)
                context['regs'].append(itemContext)

            elif isinstance(item, MemNode):
                itemContext['node_type'] =  "MEM"
                self.gen_memitem(item, context=itemContext)
                context['mems'].append(itemContext)

            elif isinstance(item, AddrmapNode):
                itemContext['node_type'] = "ADDRMAP"
                context['exts'].append(itemContext)

            elif isinstance(item, RegfileNode):
                 itemContext['node_type'] = "REGFILE"
                 self.gen_rfitem(item, context=itemContext)
                 context['regf'].append(itemContext)

            # append item contect to items list
            context['items'].append(AttributeDict(itemContext))

    # =========================================================================
    def set_item_dimmentions(self, item: AddressableNode, itemContext: dict):
        #-------------------------------------
        dim_n = 1
        dim_m = 1
        dim = 0

        if item.is_array:
            if len(item.array_dimensions) == 2:
                dim_n = item.array_dimensions[0]
                dim_m = item.array_dimensions[1]
                dim = 2
            elif len(item.array_dimensions) == 1:
                dim_n = 1
                dim_m = item.array_dimensions[0]
                dim = 1

        itemContext["elements"] = dim_n * dim_m
        itemContext["dim_n"] = dim_n
        itemContext["dim_m"] = dim_m
        itemContext["dim"] = dim


    # =========================================================================
    # def gen_extitem (self, extx: AddrmapNode, context):
    #     extx.get_property("desyrdl_interface")

    # =========================================================================
    def gen_regitem (self, regx: RegNode, context):
        #-------------------------------------
        totalwidth = 0
        n_fields = 0
        reset = 0
        fields = list()
        for field in regx.fields():
            totalwidth += field.get_property("fieldwidth")
            n_fields += 1
            field_reset = 0
            fieldContext = dict()
            mask = self.bitmask(field.get_property("fieldwidth"))
            mask = mask << field.low
            fieldContext['mask'] = mask
            fieldContext['mask_hex'] = hex(mask)
            if(field.get_property("reset")):
                field_reset = field.get_property("reset")
                reset |= (field_reset << field.low) & mask
            fieldContext['node'] = field
            self.gen_fielditem(field, fieldContext)
            fieldC = AttributeDict(fieldContext)
            fields.append(fieldC)
            #print(fieldC.mask)

        context["width"] = totalwidth
        context["dtype"] = regx.get_property("desyrdl_data_type") or "uint"
        context["signed"] = self.get_data_type_sign(regx)
        context["fixedpoint"] = self.get_data_type_fixed(regx)
        if not regx.has_sw_writable and regx.has_sw_readable:
            context["rw"] = "RO"
        elif regx.has_sw_writable and not regx.has_sw_readable:
            context["rw"] = "WO"
        else:
            context["rw"] = "RW"
        context["reset"] = reset
        context["reset_hex"] = hex(reset)
        context["fields"] = fields

    # =========================================================================
    def gen_fielditem (self, fldx: FieldNode, context):
        context['node']  = fldx
        context["ftype"] = self.get_ftype(fldx)
        context["width"] = fldx.get_property("fieldwidth")
        context["sw"] = fldx.get_property("sw").name
        context["hw"] = fldx.get_property("hw").name
        if not fldx.is_sw_writable and fldx.is_sw_readable:
            context["rw"] = "RO"
        elif fldx.is_sw_writable and not fldx.is_sw_readable:
            context["rw"] = "WO"
        else:
            context["rw"] = "RW"
        context["const"] = 1 if fldx.get_property("hw").name == "na" or fldx.get_property("hw").name == "r" else 0
        context["reset"] = 0 if fldx.get_property("reset") is None else self.to_int32(fldx.get_property("reset"))
        context["reset_hex"] = hex(context["reset"])
        context["decrwidth"] = fldx.get_property("decrwidth") if fldx.get_property("decrwidth") is not None else 1
        context["incrwidth"] = fldx.get_property("incrwidth") if fldx.get_property("incrwidth") is not None else 1
        context["dtype"] = fldx.get_property("desyrdl_data_type") or "uint"
        context["signed"] = self.get_data_type_sign(fldx)
        context["fixedpoint"] = self.get_data_type_fixed(fldx)
        context["desc"] = fldx.get_property("desc") or ""
        context["desc_html"] = fldx.get_html_desc(self.md) or ""


    # =========================================================================
    def gen_memitem (self, memx: MemNode, context):

        context["entries"] = memx.get_property("mementries")
        context["addresses"] = memx.get_property("mementries") * 4
        context["datawidth"] = memx.get_property("memwidth")
        context["addrwidth"] = ceil(log2(memx.get_property("mementries") * 4))
        context["sw"] = memx.get_property("sw").name
        if not memx.is_sw_writable and memx.is_sw_readable:
            context["rw"] = "RO"
        elif memx.is_sw_writable and not memx.is_sw_readable:
            context["rw"] = "WO"
        else:
            context["rw"] = "RW"
        context['items']  = list()
        context['regs']  = list()
        self.gen_items(memx, context)

            # =========================================================================
    def gen_rfitem (self, regf: RegfileNode, context):
        context['items']  = list()
        context['regs']  = list()
        self.gen_items(regf, context)

    # =========================================================================
    def bitmask(self,width):
        '''
        Generates a bitmask filled with '1' with bit width equal to 'width'
        '''
        mask = 0
        for i in range(width):
            mask |= (1 << i)
        return mask

    def to_int32(self,value):
        "make sure we have int32"
        masked = value & (pow(2,32)-1)
        if masked > pow(2,31):
             return -(pow(2,32)-masked)
        else:
            return masked

    def get_ftype(self, node):
        # Expects FieldNode type
        assert isinstance(node, FieldNode)

        if node.get_property("counter"):
            return "COUNTER"
        elif node.get_property("intr"):
            return "INTERRUPT"
        elif node.implements_storage:
            return "STORAGE"
        elif not node.is_virtual:
            return "WIRE"
        else:
            # error (TODO: handle as such)
            print("ERROR: can't make out the type of field for {}".format(node.get_path()))
            return "WIRE"

    def get_access_channel(self, node):
        # Starting point for finding the top node
        cur_node = node
        ch = None
        while ch is None:
            try:
                ch = cur_node.get_property("desyrdl_access_channel")
                # The line above can return 'None' without raising an exception
                assert ch is not None
            except (LookupError,AssertionError):
                cur_node = cur_node.parent
                # The RootNode is above the top node and can't have the property
                # we are looking for.
                if isinstance(cur_node, RootNode):
                    print("ERROR: Couldn't find the access channel for " + node.inst_name)
                    raise
        return ch

    def get_data_type_sign(self, node):
        datatype = str(node.get_property("desyrdl_data_type") or '')
        pattern = '(^int.*|^fixed.*)'
        if re.match(pattern, datatype):
            return 1
        else:
            return 0

    def get_data_type_fixed(self, node):
        datatype = str(node.get_property("desyrdl_data_type") or '')
        pattern_fix = '.*fixed([-]*\d*)'
        pattern_fp = 'float'
        srch_fix = re.search(pattern_fix, datatype.lower())

        if srch_fix:
            if srch_fix.group(1) == '':
                return ''
            else:
                return int(srch_fix.group(1))

        if pattern_fp == datatype.lower():
            return 'IEEE754'

        return 0


# Types, names and counts are needed. Clear after each exit_Addrmap
class TemplateListener(DesyListener):
    def exit_Addrmap(self, node : AddrmapNode):
        super().exit_Addrmap(node)

#         if isinstance(node.parent, RootNode):
#             print(" ---- Root name:" + str(node.inst_name))

        # generate if no property set or is set to true
        # if node.get_property('desyrdl_generate_hdl') is None or \
        #    node.get_property('desyrdl_generate_hdl') is True:
        #     self.process_templates(node)


#         template= """========
# {%- for item in items %}
# {%- if item.type == "REGFILE" %}
#         Regfile {% endif %}
# {{ item.node.inst_name }} : {{ item.node.raw_absolute_address }} : {{ item.node.size }}
# {%- endfor %}
# ========"""
#         template2= """
# ========
# {{path_notop}}
# ========
# {%- for reg in regs %}
# {{ path_addrmap_name }}.{{ reg.inst_name }} : {{ reg.absolute_address }} : {{ reg.node.size }} - {{ reg.desc }}
#         {%- for field in reg.fields %}
#         {{ field.node.type_name }} [{{ field.node.high }}:{{ field.node.low}}]
#         {%- endfor %}
# {%- endfor %}
# {%- for item in items %}
# {%- if item.node_type == "REGFILE" %}
#         REGFILE {{item.name}} {{item.path}}
# {%- endif %}
# {%- if item.node_type == "ADDRMAP" %}
#        PARENT {{interface_type}}-{{ item.desyrdl_interface }} {{ item.inst_name }}
# {%- endif %}
# {%- endfor %}"""
#         template3= """
# ========
# {{path_notop}}
# ========
# {%- for item in items %}
#         {%- if item.dim == 0 and item.node_type == "REGFILE"  %}
# REGFILE {{item.name}} {{item.path}}
#         {%- for rfreg in item.regs %}
#             REGISTER : {{rfreg.inst_name}}
# {%- endfor %}
#         {%- endif %}
#         {%- for idx in range(item.dim_m) if item.dim == 1 and item.node_type == "REGFILE"  %}

#         REGFILE {{item.name}}.{{idx}} {{item.path}}
#              {%- for rfreg in item.regs %}
#             REGISTER : {{rfreg.inst_name}}
# {%- endfor %}
#         {%- endfor %}
# {%- endfor %}"""

#         # print("--------")
#         # print("Node name:" + str(node.inst_name))

#         if isinstance(node.parent, RootNode):
#             print(" ---- Root name:" + str(node.inst_name))

#         j2_template = Template(template3)

#         print(j2_template.render(self.context))
