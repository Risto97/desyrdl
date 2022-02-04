#!/usr/bin/env python
# --------------------------------------------------------------------------- #
#           ____  _____________  __                                           #
#          / __ \/ ____/ ___/\ \/ /                 _   _   _                 #
#         / / / / __/  \__ \  \  /                 / \ / \ / \                #
#        / /_/ / /___ ___/ /  / /               = ( M | S | K )=              #
#       /_____/_____//____/  /_/                   \_/ \_/ \_/                #
#                                                                             #
# --------------------------------------------------------------------------- #
# @copyright Copyright 2021 DESY
# SPDX-License-Identifier: Apache-2.0
# --------------------------------------------------------------------------- #
# @date 2021-04-07
# @author Michael Buechler <michael.buechler@desy.de>
# @author Lukasz Butkowski <lukasz.butkowski@desy.de>
# --------------------------------------------------------------------------- #
"""DesyRdl main class.

Create context dictionaries for each address space node.
Context dictionaries are used by the template engine.
"""

import re
from math import ceil, log2
from pathlib import Path  # get filenames

from systemrdl import RDLListener
from systemrdl.node import (AddrmapNode, FieldNode,  # AddressableNode,
                            MemNode, RegfileNode, RegNode, RootNode)


class DesyListener(RDLListener):

    # formatter: RdlFormatter instance
    # templates: array of tuples (tpl_file, tpl_tplstr)
    # out_dir: path where to put output files
    def __init__(self, formatter, templates, out_dir):
        for t,tplstr in templates:
            assert isinstance(t, Path)
        assert isinstance(out_dir, Path)

        self.templates = templates
        self.out_dir = out_dir
        self.generated_files = list()

        self.formatter = formatter

        self.init_context()

    def init_context(self):
        self.regitems = list()
        self.memitems = list()
        self.extitems = list()
        self.regtypes = list()
        self.memtypes = list()
        self.regcount = list()

        # increase and decreaes a pointer as we go through the register model
        self.context_pointer = -1

    def process_templates(self, node):
        for tpl,tplstr in self.templates:
            with tpl.open('r') as f_in:
                s_in = f_in.read()

            s_out = self.formatter.format(s_in, **self.context)

            # get .in suffix and remove it, process only .in files
            suffix = "".join(tpl.suffix)
            if suffix != ".in":
                continue

            out_file = self.formatter.format(tplstr, **self.context)
            out_path = Path(self.out_dir / out_file)

            with out_path.open('w') as f_out:
                f_out.write(s_out)
                if out_path not in self.generated_files:
                    self.generated_files.append(out_path)

    def enter_Addrmap(self, node):
        self.regtypes.append(dict())
        self.memtypes.append(dict())
        self.regitems.append(list())
        self.memitems.append(list())
        self.extitems.append(list())
        self.regcount.append(0)

        self.context_pointer = self.context_pointer+1

        print(f'entering addrmap {node.inst_name}, context_pointer now {self.context_pointer}')
        print(f'regtypes len: {len(self.regtypes)}')

    # types are in the dictionary on the top of the stack
    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes[self.context_pointer]:
                self.memtypes[self.context_pointer][node.type_name] = node

        if isinstance(node, RegNode) and not node.external:
            if node.type_name not in self.regtypes[self.context_pointer]:
                print(f'adding type {node.type_name} to {self.regtypes[self.context_pointer]}')

                self.regtypes[self.context_pointer][node.type_name] = node

    def exit_Addrmap(self, node):

        # There is no need for more than the generators before the actual
        # context is created.
        self.regitems[self.context_pointer].extend(self.gen_node_names(node, [RegNode], False))
        self.memitems[self.context_pointer].extend(self.gen_node_names(node, [MemNode], True, first_only=False))
        self.extitems[self.context_pointer].extend(self.gen_node_names(node, [AddrmapNode, RegfileNode, RegNode], True, first_only=False))

        print(f"path_segment = {node.get_path_segment()}")
        print(f"node.inst_name = {node.inst_name}")
        print(f"node.type_name = {node.type_name}")

    # yields a tuple (i, node) for each child of node that matches a list of
    # types and is either external or internal
    def gen_node_names(self, node, types, external, first_only=True):
        # filter children according to arguments; result is an iterable
        def is_wanted_child(child):
            return type(child) in types and child.external is external
        children = filter(is_wanted_child, node.children(unroll=True))

        i = 0
        for child in children:
            # if the child is an array, only take
            # the first element, otherwise return
            if child.is_array and first_only is True:
                if any(k != 0 for k in child.current_idx):
                    continue
            yield (i, child)
            i += 1

    def gen_regitems(self, gen_items):
        # For indexing of flattened arrays in VHDL port definitions.
        # Move to a dict() or improve VHDL code.
        index = 0

        # apparently there is no need to do enumerate(gen_items)
        for i, regx in gen_items:

            dim_n = 1
            dim_m = 1
            dim = 1
            if regx.is_array:
                if len(regx.array_dimensions) == 2:
                    dim_n = regx.array_dimensions[0]
                    dim_m = regx.array_dimensions[1]
                    dim = 3
                elif len(regx.array_dimensions) == 1:
                    dim_n = 1
                    dim_m = regx.array_dimensions[0]
                    dim = 2

            elements = dim_n * dim_m

            self.regcount[self.context_pointer] += elements

            context = dict()

            addrmap_segments = regx.get_path_segments(array_suffix='', empty_array_suffix='')
            addrmap = addrmap_segments[-2]
            addrmap_name = ".".join([x for i,x in enumerate(addrmap_segments[-2:])])
            addrmap_full = ".".join([x for i,x in enumerate(addrmap_segments[:-1])])
            addrmap_full_name = ".".join([x for i,x in enumerate(addrmap_segments)])
            addrmap_full_notop = ".".join([x for i,x in enumerate(addrmap_segments[1:-1])])
            addrmap_full_notop_name = ".".join([x for i,x in enumerate(addrmap_segments[1:])])

            fields = [f for f in self.gen_fields(regx)]

            context["i"] = i
            context["name"] = regx.inst_name
            context["type"] = regx.type_name
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["addrmap_name"] = addrmap_name
            context["addrmap_full_name"] = addrmap_full_name
            context["addrmap_full_notop"] = addrmap_full_notop
            context["addrmap_full_notop_name"] = addrmap_full_notop_name
            context["reladdr"] = regx.address_offset
            context["absaddr"] = regx.absolute_address

            context["reg"] = regx
            context["dim_n"] = dim_n
            context["dim_m"] = dim_m
            context["dim"] = dim
            context["elements"] = elements
            context["fields"] = fields
            context["rw"] = "RW" if regx.has_sw_writable else "RO"
            context["width"] = regx.get_property("regwidth")
            context["signed"] = self.get_data_type_sign(regx)
            context["fixedpoint"] = self.get_data_type_fixed(regx)
            # "internal_offset" is needed for indexing of flattened arrays in VHDL
            # port definitions. Improve VHDL code to get rid of it.
            context["index"] = index
            index = index + elements

            context["desyrdl_access_channel"] = self.get_access_channel(regx)

            # add all non-native explicitly set properties
            for p in regx.list_properties(include_native=False):
                assert p not in context
                context[p] = regx.get_property(p)

            yield context

    def gen_memitems(self, gen_items):
        for i, memx in gen_items:

            context = dict()

            addrmap_segments = memx.get_path_segments(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap = addrmap_segments[-2]
            addrmap_name = ".".join([x for i,x in enumerate(addrmap_segments[-2:])])
            addrmap_full = ".".join([x for i,x in enumerate(addrmap_segments[:-1])])
            addrmap_full_name = ".".join([x for i,x in enumerate(addrmap_segments)])
            addrmap_full_notop = ".".join([x for i,x in enumerate(addrmap_segments[1:-1])])
            addrmap_full_notop_name = ".".join([x for i,x in enumerate(addrmap_segments[1:])])

            context["i"] = i
            context["name"] = memx.inst_name
            context["type"] = memx.type_name
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["addrmap_name"] = addrmap_name
            context["addrmap_full_name"] = addrmap_full_name
            context["addrmap_full_notop"] = addrmap_full_notop
            context["addrmap_full_notop_name"] = addrmap_full_notop_name
            context["reladdr"] = memx.address_offset
            context["absaddr"] = memx.absolute_address

            context["mem"] = memx
            context["entries"] = memx.get_property("mementries")
            context["addresses"] = memx.get_property("mementries") * 4
            context["datawidth"] = memx.get_property("memwidth")
            context["addrwidth"] = ceil(log2(memx.get_property("mementries") * 4))
            context["sw"] = memx.get_property("sw").name
            # virtual registers, e.g. for DMA regions
            gen_vregs = self.gen_node_names(memx, [RegNode], False)
            context["vregs"] = [x for x in self.gen_regitems(gen_vregs)]

            context["desyrdl_access_channel"] = self.get_access_channel(memx)
            if not memx.is_sw_writable and memx.is_sw_readable:
                context["rw"] = "RO"
            elif memx.is_sw_writable and not memx.is_sw_readable:
                context["rw"] = "WO"
            else:
                context["rw"] = "RW"

            # add all non-native explicitly set properties
            for p in memx.list_properties(include_native=False):
                assert p not in context
                context[p] = memx.get_property(p)

            yield context

    def gen_extitems(self, gen_items):
        for i, extx in gen_items:

            context = dict()

            addrmap_segments = extx.get_path_segments(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap = addrmap_segments[-2]
            addrmap_name = ".".join([x for i,x in enumerate(addrmap_segments[-2:])])
            addrmap_full = ".".join([x for i,x in enumerate(addrmap_segments[:-1])])
            addrmap_full_name = ".".join([x for i,x in enumerate(addrmap_segments)])
            addrmap_full_notop = ".".join([x for i,x in enumerate(addrmap_segments[1:-1])])
            addrmap_full_notop_name = ".".join([x for i,x in enumerate(addrmap_segments[1:])])

            context["i"] = i
            context["name"] = extx.inst_name
            context["type"] = extx.type_name
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["addrmap_name"] = addrmap_name
            context["addrmap_full_name"] = addrmap_full_name
            context["addrmap_full_notop"] = addrmap_full_notop
            context["addrmap_full_notop_name"] = addrmap_full_notop_name
            context["reladdr"] = extx.address_offset
            context["absaddr"] = extx.absolute_address

            context["ext"] = extx
            context["size"] = int(extx.total_size)
            context["total_words"] = int(extx.total_size/4)
            context["addrwidth"] = ceil(log2(extx.size))

            context["desyrdl_access_channel"] = self.get_access_channel(extx)

            # add all non-native explicitly set properties
            for p in extx.list_properties(include_native=False):
                if p not in context:
                    context[p] = extx.get_property(p)

            yield context

    def gen_regtypes(self, types):
        for i, regx in enumerate(types):
            fields = [f for f in self.gen_fields(regx)]
            fields_count = len(fields)
            reg_sign = self.get_data_type_sign(regx)
            context = dict()

            context["i"] = i
            context["regtype"] = regx
            context["fields"] = fields
            context["fields_count"] = fields_count
            context["name"] = regx.type_name
            context["signed"] = reg_sign
            context["fixedpoint"] = self.get_data_type_fixed(regx)

            context["desyrdl_access_channel"] = self.get_access_channel(regx)
            if fields_count > 1:
                map_out = 0
            else:
                if reg_sign == 0:
                    map_out = 1
                else:
                    map_out = 2

            context["map_out"] = map_out

            # add all non-native explicitly set properties
            for p in regx.list_properties(include_native=False):
                assert p not in context
                context[p] = regx.get_property(p)

            yield context

    def gen_memtypes(self, types):
        for i, memx in enumerate(types):
            context = dict()

            context["mem"] = memx
            context["mementries"] = memx.get_property("mementries")
            context["memwidth"] = memx.get_property("memwidth")
            context["datawidth"] = memx.get_property("memwidth")
            context["addresses"] = memx.get_property("mementries") * 4
            context["addrwidth"] = ceil(log2(memx.get_property("mementries") * 4))

            context["desyrdl_access_channel"] = self.get_access_channel(memx)

            # add all non-native explicitly set properties
            for p in memx.list_properties(include_native=False):
                assert p not in context
                context[p] = memx.get_property(p)

            yield context

    def gen_fields(self, node):
        for i, fldx in enumerate(node.fields()):

            context = dict()

            context["i"] = i
            context["regtype"] = fldx.parent
            context["field"] = fldx
            context["ftype"] = self.get_ftype(fldx)
            context["width"] = fldx.get_property("fieldwidth")
            context["low"] = fldx.low
            context["high"] = fldx.high
            context["we"] = 0 if fldx.get_property("we") is False else 1
            context["sw"] = fldx.get_property("sw").name
            context["hw"] = fldx.get_property("hw").name
            context["const"] = 1 if fldx.get_property("hw").name == "na" or fldx.get_property("hw").name == "r" else 0
            context["reset"] = 0 if fldx.get_property("reset") is None else fldx.get_property("reset")
            context["decrwidth"] = fldx.get_property("decrwidth") if fldx.get_property("decrwidth") is not None else 1
            context["incrwidth"] = fldx.get_property("incrwidth") if fldx.get_property("incrwidth") is not None else 1
            context["name"] = fldx.type_name
            # FIXME parent should be used as default if not defined in field
            context["signed"] = self.get_data_type_sign(fldx)
            context["fixedpoint"] = self.get_data_type_fixed(fldx)
            # add all non-native explicitly set properties
            for p in node.list_properties(include_native=False):
                assert p not in context
                context[p] = node.get_property(p)

            yield context

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
        pattern = '.*fixed([-]*\d*)'
        srch = re.search(pattern, datatype)
        if srch:
            if srch.group(1) == '':
                return ''
            else:
                return int(srch.group(1))
        else:
            return 0

    def get_generated_files(self):
        return self.generated_files


# Types, names and counts are needed. Clear after each exit_Addrmap
class VhdlListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        self.context = dict(
                node=node,
                regtypes=[x for x in self.gen_regtypes(self.regtypes[self.context_pointer].values())],
                memtypes=[x for x in self.gen_memtypes(self.memtypes[self.context_pointer].values())],
                regitems=[x for x in self.gen_regitems(self.regitems[self.context_pointer])],
                memitems=[x for x in self.gen_memitems(self.memitems[self.context_pointer])],
                extitems=[x for x in self.gen_extitems(self.extitems[self.context_pointer])],
                n_regtypes=len(self.regtypes[self.context_pointer]),
                n_regitems=len(self.regitems[self.context_pointer]),
                n_regcount=self.regcount[self.context_pointer],
                n_memtypes=len(self.memtypes[self.context_pointer]),
                n_memitems=len(self.memitems[self.context_pointer]),
                n_extitems=len(self.extitems[self.context_pointer]))

        # add all non-native explicitly set properties
        for p in node.list_properties(include_native=False):
            assert p not in self.context
            print(f"exit_Addrmap {node.inst_name}: Adding non-native property {p}")
            self.context[p] = node.get_property(p)

        # generate if no property set or is set to true
        if node.get_property('desyrdl_generate_hdl') is None or \
           node.get_property('desyrdl_generate_hdl') is True:
            self.process_templates(node)

        self.context_pointer = self.context_pointer-1
        print(f'leaving addrmap {node.inst_name}, context_pointer now {self.context_pointer}')


class MapfileListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        if isinstance(node.parent, RootNode):
            assert self.context_pointer == 0

            all_regtypes = [y for x in self.regtypes for y in self.gen_regtypes(x.values())]
            all_memtypes = [y for x in self.memtypes for y in self.gen_memtypes(x.values())]
            all_regitems = [y for x in self.regitems for y in self.gen_regitems(x)]
            all_memitems = [y for x in self.memitems for y in self.gen_memitems(x)]
            all_extitems = [y for x in self.extitems for y in self.gen_extitems(x)]

            self.context = dict(
                    node=node,
                    regtypes=all_regtypes,
                    memtypes=all_memtypes,
                    regitems=all_regitems,
                    memitems=all_memitems,
                    extitems=all_extitems,
                    n_regtypes=len(all_regtypes),
                    n_regitems=len(all_regitems),
                    n_regcount=sum(self.regcount),
                    n_memtypes=len(all_memtypes),
                    n_memitems=len(all_memitems),
                    n_extitems=len(all_extitems))

            # add all non-native explicitly set properties
            for p in node.list_properties(include_native=False):
                assert p not in self.context
                print(f"exit_Addrmap {node.inst_name}: Adding non-native property {p}")
                self.context[p] = node.get_property(p)

            # The mapfile output filename is a template and relies on the access
            # channel property.
            if "desyrdl_access_channel" not in self.context:
                self.context["desyrdl_access_channel"] = self.get_access_channel(node)

            self.process_templates(node)

        self.context_pointer = self.context_pointer-1
        print(f'leaving addrmap {node.inst_name}, context_pointer now {self.context_pointer}')
