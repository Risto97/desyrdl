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
import copy
from math import ceil, log2
from pathlib import Path

import jinja2
from systemrdl import AddressableNode, RDLListener
from systemrdl.messages import MessageHandler, MessagePrinter
from systemrdl.node import AddrmapNode, FieldNode, MemNode, RegfileNode, RegNode, RootNode

from desyrdl.rdlformatcode import DesyrdlMarkup


class AttributeDict(dict):
    """Class to convert dict to attributes of object."""

    __getattr__ = dict.get
    __setattr__ = dict.__setitem__
    __delattr__ = dict.__delitem__


class DesyListener(RDLListener):
    """
    Define a listener that will create the context dictionary based on register model hierarchy.
    which will be use later for templates rendering
    """

    def __init__(self):
        self.separator = "."

        # global context
        self.top_items = []
        self.top_regs = []
        self.top_mems = []
        self.top_exts = []
        self.top_regf = []
        self.top_intrs = []
        self.top_intrs_tree = []

        self.top_context = {}
        self.top_context['addrmaps'] = []
        self.top_context['separator'] = self.separator
        self.top_context['interface_adapters'] = []
        # local address map contect only
        self.context = {}
        # context template, with empty lists
        self.context_tpl = {}
        self.context_tpl['insts'] = []
        self.context_tpl['reg_insts'] = []
        self.context_tpl['mem_insts'] = []
        self.context_tpl['ext_insts'] = []
        self.context_tpl['rgf_insts'] = []
        self.context_tpl['reg_types'] = []
        self.context_tpl['mem_types'] = []
        self.context_tpl['ext_types'] = []
        self.context_tpl['rgf_types'] = []
        self.context_tpl['reg_type_names'] = []
        self.context_tpl['mem_type_names'] = []
        self.context_tpl['ext_type_names'] = []
        self.context_tpl['rgf_type_names'] = []
        self.context_tpl['regs'] = []
        self.context_tpl['mems'] = []
        self.context_tpl['exts'] = []
        self.context_tpl['regf'] = []
        self.context_tpl['n_regs'] = 0
        self.context_tpl['n_mems'] = 0
        self.context_tpl['n_exts'] = 0
        self.context_tpl['n_regf'] = 0
        self.context_tpl['interface_adapters'] = []
        # custon properties
        RegNode.intr_line = None
        RegNode.intr_parent = None
        RegNode.addrmap_node = None
        # parse description with markup lanugage, disable Mardown
        self.md = DesyrdlMarkup()
        message_printer = MessagePrinter()
        self.msg = MessageHandler(message_printer)

    # =========================================================================
    def init_addrmap_lists(self):
        """Intializes conectext ditionary in addrmap."""
        self.context.clear()
        self.context = copy.deepcopy(self.context_tpl)

    # =========================================================================
    def exit_Addrmap(self, node: AddrmapNode):
        """Create context dictionary when exititing address map node.

        Walks over address space tree.
        """
        self.init_addrmap_lists()
        # ------------------------------------------
        self.context['node'] = node
        self.context['type_name'] = node.type_name
        self.context['inst_name'] = node.inst_name
        self.context['type_name_org'] = (
            node.inst.original_def.type_name if node.inst.original_def is not None else node.type_name
        )

        if node.get_property('desyrdl_interface') is None:
            self.msg.warning(
                "No desyrdl_interface defined. Fallback to AXI4L.",
                node.inst.property_src_ref.get('addrmap', node.inst.def_src_ref),
            )
            self.context['interface'] = "axi4l"
        else:
            self.context['interface'] = node.get_property('desyrdl_interface')
        self.context['access_channel'] = self.get_access_channel(node)
        self.context['addrwidth'] = ceil(log2(node.size))

        self.context['desc'] = node.get_property('desc')
        self.context['desc_html'] = node.get_html_desc(self.md)

        path_segments = node.get_path_segments(array_suffix=f'{self.separator}{{index:d}}', empty_array_suffix='')
        self.context['path_segments'] = path_segments
        self.context['path'] = self.separator.join(path_segments)
        self.context['path_notop'] = self.separator.join(path_segments[1:])
        self.context['path_addrmap_name'] = path_segments[-1]

        self.set_item_dimmentions(node, self.context)
        # ------------------------------------------
        self.gen_items(node, self.context)
        self.context['regs'] = self.unroll_inst('reg_insts', self.context)
        self.context['mems'] = self.unroll_inst('mem_insts', self.context)
        self.context['regf'] = self.unroll_inst('rgf_insts', self.context)
        self.context['exts'] = self.unroll_inst('ext_insts', self.context)

        # ------------------------------------------
        self.context['n_reg_insts'] = len(self.context['reg_insts'])
        self.context['n_mem_insts'] = len(self.context['mem_insts'])
        self.context['n_ext_insts'] = len(self.context['ext_insts'])
        self.context['n_rgf_insts'] = len(self.context['rgf_insts'])

        self.context['n_regs'] = len(self.context['regs'])
        self.context['n_mems'] = len(self.context['mems'])
        self.context['n_exts'] = len(self.context['exts'])
        self.context['n_regf'] = len(self.context['regf'])

        self.context['n_regf_regs'] = 0
        for regf in self.context['regf']:
            self.context['n_regf_regs'] += len(regf['regs'])

        # ------------------------------------------
        self.top_context['addrmaps'].append(self.context.copy())
        self.top_context['access_channel'] = self.context['access_channel']
        self.top_context['interface_adapters'] = (
            self.top_context['interface_adapters'] + self.context['interface_adapters'].copy()
        )

        # update interript context with proper path only in top_contxt
        if isinstance(node.parent, RootNode):
            for intr in self.top_intrs_tree:
                print(f"intr: {intr}")
                for addrmap in self.top_context['addrmaps']:
                    self.update_intr_context(addrmap, intr)

    def update_intr_context(self, addrmap_ctx, intr_ctx):
        """Update contexs with the interrupt tree data."""
        for inst in addrmap_ctx['insts']:
            if inst.node.get_path() == intr_ctx['path']:
                inst.intr_line = intr_ctx['intr_line']
                inst['intr_opts'] = self.set_intr_options(inst)
            if isinstance(inst['node'], RegfileNode):
                for rfinst in inst['reg_insts']:
                    if rfinst['node'].get_path() == intr_ctx['path']:
                        rfinst['intr_line'] = intr_ctx['intr_line']
                        rfinst['intr_opts'] = self.set_intr_options(inst)

    def set_intr_options(self, inst):
        """Find interrupt registers and set interrupt controller options."""
        options = []
        intc_regs = ["ICR", "IAR", "IPR", "MER", "GIE", "SIE", "CIE"]
        for reg in inst.node.parent.children(unroll=False):
            if reg.inst_name.lower() in (name.lower() for name in intc_regs):
                options.append(reg.inst_name)
        return options

    # =========================================================================
    def unroll_inst(self, insts, context):
        """Unroll all registers in addrmap + regfiles.
        Recalculate index for instsances"""
        index = 0
        idx_insts = []
        instsc = []
        for inst in context[insts]:
            inst['idx'] = index
            idx_insts.append(inst)
            for idx in range(inst['elements']):
                instc = inst.copy()
                instc['idx'] = index
                instc['address_offset'] = inst['address_offset'] + inst['array_stride'] * idx
                instc['absolute_address'] = inst['absolute_address'] + inst['array_stride'] * idx
                if inst['node'].is_array:
                    instc['address_offset_high'] = instc['address_offset'] + inst['array_stride'] - 1
                    instc['absolute_address_high'] = instc['absolute_address'] + inst['array_stride'] - 1
                instsc.append(instc)
                index += 1

        context[insts] = idx_insts
        return instsc

    # =========================================================================
    def gen_items(self, node, context):
        """Genearte context dictionary for addressable instance node."""
        for item in node.children(unroll=False):
            self.gen_item(item, context)

    # =========================================================================
    def gen_item(self, item, context):
        """Genearte context dictionary for addressable instance node."""
        item_context = {}
        # common to all items values
        item_context['node'] = item
        item_context['type_name'] = item.type_name
        item_context['inst_name'] = item.inst_name
        item_context['type_name_org'] = (
            item.inst.original_def.type_name if item.inst.original_def is not None else item.type_name
        )
        item_context['access_channel'] = self.get_access_channel(item)
        item_context['address_offset'] = item.raw_address_offset
        item_context['address_offset_high'] = item.raw_address_offset + int(item.total_size) - 1
        item_context['absolute_address'] = item.raw_absolute_address
        item_context['absolute_address_high'] = item.raw_absolute_address + int(item.total_size) - 1
        item_context['array_stride'] = item.array_stride if item.array_stride is not None else 0
        item_context['total_size'] = item.total_size
        item_context['total_words'] = int(item.total_size / 4)
        # default
        item_context["width"] = 32
        item_context["dtype"] = "uint"
        item_context["signed"] = 0
        item_context["fixedpoint"] = 0
        item_context["rw"] = "RW"

        item_context['desc'] = item.get_property("desc")
        item_context['desc_html'] = item.get_html_desc(self.md)

        self.set_item_dimmentions(item, item_context)

        # add all non-native explicitly set properties
        for prop in item.list_properties(list_all=True):
            item_context[prop] = item.get_property(prop)

        # item specyfic context
        if isinstance(item, RegNode):
            item_context['node_type'] = "REG"
            self.gen_regitem(item, context=item_context)
            context['reg_insts'].append(item_context)
            if item.type_name not in context['reg_type_names']:
                context['reg_type_names'].append(item.type_name)
                context['reg_types'].append(item_context)

        elif isinstance(item, MemNode):
            item_context['node_type'] = "MEM"
            self.gen_memitem(item, context=item_context)
            context['mem_insts'].append(item_context)
            if item.type_name not in context['mem_type_names']:
                context['mem_type_names'].append(item.type_name)
                context['mem_types'].append(item_context)

        elif isinstance(item, AddrmapNode):
            item_context['node_type'] = "ADDRMAP"
            self.gen_extitem(item, context=item_context)
            context['ext_insts'].append(item_context)
            print(f"{item.inst_name }: {item_context['interface'] } - {context['interface']}")
            if (
                context['interface'] is not None
                and item_context['interface'] is not None
                and item_context['interface'].lower() != context['interface'].lower()
            ):
                adapter_name = context['interface'].lower() + "_to_" + item_context['interface'].lower()
                if adapter_name not in context['interface_adapters']:
                    context['interface_adapters'].append(adapter_name)
            if item.type_name not in context['ext_type_names']:
                context['ext_type_names'].append(item.type_name)
                context['ext_types'].append(item_context)

        elif isinstance(item, RegfileNode):
            item_context['node_type'] = "REGFILE"
            self.gen_rfitem(item, context=item_context)
            context['rgf_insts'].append(item_context)
            if item.type_name not in context['rgf_type_names']:
                context['rgf_type_names'].append(item.type_name)
                context['rgf_types'].append(item_context)

        # append item contect to items list
        context['insts'].append(AttributeDict(item_context))

    # =========================================================================
    def set_item_dimmentions(self, item: AddressableNode, item_context: dict):
        """Based on array properties set dimensions in item context."""
        # -------------------------------------
        dim_n = 1
        dim_m = 1
        dim = 1

        if item.is_array:
            if len(item.array_dimensions) == 2:  # noqa: PLR2004
                dim_n = item.array_dimensions[0]
                dim_m = item.array_dimensions[1]
                dim = 3
            elif len(item.array_dimensions) == 1:
                dim_n = 1
                dim_m = item.array_dimensions[0]
                dim = 2

        item_context['array_stride'] = item.array_stride if item.array_stride is not None else 0
        item_context["elements"] = dim_n * dim_m
        item_context["dim_n"] = dim_n
        item_context["dim_m"] = dim_m
        item_context["dim"] = dim
        # chekck if addrmap stride is set in case of addrmap arrays
        if isinstance(item, AddrmapNode) and dim > 1:
            addr_size = pow(2, ceil(log2(item.size))) - 1
            if addr_size & item.array_stride:
                self.msg.error(
                    f"\nOnly full address alignment is supported in addrmap array instance, current stide 0x{item.array_stride:>X}.\nSet stride minimum or n(0...N) times of += 0x{addr_size+1:>X} in parent addrmap.",
                    item.inst.property_src_ref.get('addrmap', item.inst.inst_src_ref),
                )
                exit(-1)

    # =========================================================================
    def gen_extitem(self, extx: AddrmapNode, context):
        """Genrate context specyfic for AddrmapNode items."""
        context['interface'] = extx.get_property('desyrdl_interface')
        context['access_channel'] = self.get_access_channel(extx)
        context['addrwidth'] = ceil(log2(extx.size))

    # =========================================================================
    def gen_regitem(self, regx: RegNode, context):
        """Genrate context specyfic for RegNode items."""
        totalwidth = 0
        n_fields = 0
        reset = 0
        fields = []
        # context
        context["dtype"] = regx.get_property('desyrdl_data_type', default='uint')
        context["intr"] = regx.is_interrupt_reg
        context["intrch"] = regx.get_property('desyrdl_intr_line', default=0)
        if regx.is_interrupt_reg:
            self.top_intrs.append(regx)  # TMP stores interrupt nodes
            regx.intr_line = []
            regx.intr_line.append(regx.get_property('desyrdl_intr_line', default=0))
            intr_tree = {'path': regx.get_path(),
                         'intr_line': regx.intr_line,
                         'parent': None}
            lintr = list(filter(lambda intrit: intrit[1]['path'] == regx.get_path(), enumerate(self.top_intrs_tree)))
            if not lintr:  # add only if not already on the list due to next intr tree insertion in field
                self.top_intrs_tree.append(intr_tree)
            context["intr_line"] = regx.intr_line
            print(f"++adding intr to top {intr_tree}")

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
        # fields
        for field in regx.fields():
            totalwidth = max(totalwidth, field.high)
            n_fields += 1
            field_reset = 0
            field_context = {}
            mask = self.bitmask(field.get_property('fieldwidth'))
            mask = mask << field.low
            field_context['mask'] = mask
            field_context['mask_hex'] = hex(mask)
            if field.get_property('reset'):
                field_reset = field.get_property('reset')
                reset |= (field_reset << field.low) & mask
            field_context['node'] = field
            self.gen_fielditem(field, field_context)
            fld = AttributeDict(field_context)
            fields.append(fld)

        context["width"] = totalwidth+1
        context["fields"] = fields
        context["fields_count"] = len(fields)

    # =========================================================================
    def gen_fielditem(self, fldx: FieldNode, context):
        """Genrate context specyfic for FieldNode items."""
        for prop in fldx.list_properties(list_all=True):
            context[prop] = fldx.get_property(prop)
        context['node'] = fldx
        context['type_name'] = fldx.type_name
        context['inst_name'] = fldx.inst_name
        context['type_name_org'] = (
            fldx.inst.original_def.type_name if fldx.inst.original_def is not None else fldx.type_name
        )
        context['width'] = fldx.get_property('fieldwidth')
        context['sw'] = fldx.get_property('sw').name
        context['hw'] = fldx.get_property('hw').name
        if not fldx.is_sw_writable and fldx.is_sw_readable:
            context['rw'] = "RO"
        elif fldx.is_sw_writable and not fldx.is_sw_readable:
            context['rw'] = "WO"
        else:
            context['rw'] = "RW"
        context['const'] = 1 if fldx.get_property('hw').name in ('na', 'r') else 0
        context['reset'] = 0 if fldx.get_property('reset') is None else self.to_int32(fldx.get_property('reset'))
        context['reset_hex'] = hex(context['reset'])
        context['low'] = fldx.low
        context['high'] = fldx.high
        context['intrtype'] = fldx.get_property('intr type').name if fldx.get_property('intr type') is not None else None
        context['intr_line'] = fldx
        # interurpt next for tree
        if fldx.get_property('next') and context['intrtype'] is not None:
            next_obj = fldx.get_property('next')
            next_path = next_obj.node.get_path()
            intr_line = list(fldx.parent.intr_line)
            intr_line.append(fldx.low)
            # we look for interrupt regs on the list, get_propert returns wrong object, compiler bug?
            # 'next' interrupt regs are already processed - bottom to top
            intr_tree = {'path': next_path,
                         'intr_line': intr_line,
                         'parent': fldx}
            lintr = list(filter(lambda intrit: intrit[1]['path'] == next_path, enumerate(self.top_intrs_tree)))
            if lintr:
                self.top_intrs_tree[lintr[0][0]] = intr_tree
            else:
                self.top_intrs_tree.append(intr_tree)

        context['onread'] = fldx.get_property('onread')
        context['onwrite'] = fldx.get_property('onwrite')
        context['singlepulse'] = fldx.get_property('singlepulse')
        context['decrwidth'] = fldx.get_property('decrwidth') if fldx.get_property('decrwidth') is not None else 0
        context['incrwidth'] = fldx.get_property('incrwidth') if fldx.get_property('incrwidth') is not None else 0
        context['decrvalue'] = fldx.get_property('decrvalue') if fldx.get_property('decrvalue') is not None else 0
        context['incrvalue'] = fldx.get_property('incrvalue') if fldx.get_property('incrvalue') is not None else 0
        context['dtype'] = fldx.get_property('desyrdl_data_type') or 'uint'
        context['signed'] = self.get_data_type_sign(fldx)
        context['fixedpoint'] = self.get_data_type_fixed(fldx)
        context['desc'] = fldx.get_property("desc") or ""
        context['desc_html'] = fldx.get_html_desc(self.md) or ""
        # check if we flag is set
        if (
            not fldx.is_virtual
            and fldx.is_hw_writable
            and fldx.is_sw_writable
            and not fldx.get_property('we')
            and fldx.parent.parent.get_property('desyrdl_generate_hdl') is True
            and not fldx.parent.is_interrupt_reg
        ):
            self.msg.warning(
                f"missing 'we' flag. 'sw = {fldx.get_property('sw').name}' "
                f"and 'hw = {fldx.get_property('hw').name}' both can write to the register filed. "
                f"'sw' will be always overwritten.\nRegister: {fldx.parent.inst_name}",
                fldx.inst.property_src_ref.get('we', fldx.inst.def_src_ref),
            )

    # =========================================================================
    def gen_memitem(self, memx: MemNode, context):
        """Genrate context specyfic for MemNode items."""
        context['entries'] = memx.get_property('mementries')
        context['addresses'] = memx.get_property('mementries') * 4
        context['datawidth'] = memx.get_property("memwidth")
        context['addrwidth'] = ceil(log2(memx.get_property('mementries') * 4))
        context['width'] = context['datawidth']
        context['dtype'] = memx.get_property('desyrdl_data_type') or 'uint'
        context['signed'] = self.get_data_type_sign(memx)
        context['fixedpoint'] = self.get_data_type_fixed(memx)
        context['sw'] = memx.get_property('sw').name
        if not memx.is_sw_writable and memx.is_sw_readable:
            context['rw'] = "RO"
        elif memx.is_sw_writable and not memx.is_sw_readable:
            context['rw'] = "WO"
        else:
            context['rw'] = "RW"
        context['insts'] = []
        context['reg_insts'] = []
        context['regs'] = []
        context['reg_types'] = []
        context['reg_type_names'] = []
        self.gen_items(memx, context)
        context['regs'] = self.unroll_inst('reg_insts', context)
        context['n_reg_insts'] = len(context['reg_insts'])
        context['n_regs'] = len(context['regs'])

    # =========================================================================
    def gen_rfitem(self, regf: RegfileNode, context):
        """Genrate context specyfic for RegfileNode items."""
        context['insts'] = []
        context['reg_insts'] = []
        context['regs'] = []
        context['reg_types'] = []
        context['reg_type_names'] = []
        self.gen_items(regf, context)
        context['regs'] = self.unroll_inst('reg_insts', context)
        context['n_reg_insts'] = len(context['reg_insts'])
        context['n_regs'] = len(context['regs'])

    # =========================================================================
    def bitmask(self, width):
        """Generate a bitmask filled with '1' with bit width equal to 'width'."""
        mask = 0
        for i in range(width):
            mask |= 1 << i
        return mask

    # =========================================================================
    def to_int32(self, value):
        """Make sure we have int32."""
        masked = value & (pow(2, 32) - 1)
        if masked > pow(2, 31):
            return -(pow(2, 32) - masked)
        return masked

    # =========================================================================
    def get_access_channel(self, node):
        """Set proper access channel for the node based on parent."""
        # Starting point for finding the top node
        cur_node = node
        ch = None
        while ch is None:
            try:
                ch = cur_node.get_property('desyrdl_access_channel')
                # The line above can return 'None' without raising an exception
                if ch is None:
                    message = "No access channel"
                    raise ValueError(message)
            except ValueError:
                cur_node = cur_node.parent
                if isinstance(cur_node, RootNode):
                    return 0
            except LookupError:
                cur_node = cur_node.parent
                # The RootNode is above the top node and can't have the property
                # we are looking for.
                if isinstance(cur_node, RootNode):
                    print("ERROR: Couldn't find the access channel for " + node.inst_name)
                    raise
        return ch

    # =========================================================================
    def get_data_type_sign(self, node):
        """Get data sign value from DesyRDL datatype."""
        datatype = str(node.get_property('desyrdl_data_type') or '')
        pattern = "(^int.*|^fixed.*)"
        if re.match(pattern, datatype):
            return 1
        return 0

    # =========================================================================
    def get_data_type_fixed(self, node):
        """Get data fixpoint value from DesyRDL datatype."""
        datatype = str(node.get_property('desyrdl_data_type') or '')
        pattern_fix = ".*fixed([0-9-]*)"
        pattern_fp = 'float'
        srch_fix = re.search(pattern_fix, datatype.lower())

        if srch_fix:
            if srch_fix.group(1) == '':
                return ''
            return int(srch_fix.group(1))

        if pattern_fp == datatype.lower():
            return 'IEEE754'

        return 0


class DesyRdlProcessor(DesyListener):
    """
    Main class to process templates while walking trough the address tree.
    Inherits from DesyListener and SystemRDL Listener.
    """

    def __init__(self, tpl_dir, lib_dir, out_dir, out_formats):
        super().__init__()

        self.out_formats = out_formats
        self.lib_dir = lib_dir
        self.out_dir = out_dir

        self.generated_files = {}
        self.generated_files['vhdl'] = []
        self.generated_files['vhdl_dict'] = {}
        self.generated_files['cocotb'] = []
        self.generated_files['map'] = []
        self.generated_files['h'] = []
        self.generated_files['adoc'] = []
        self.generated_files['tcl'] = []
        self.generated_files['vhdl_dict']['desyrdl'] = []  # inset desyrdl key so it is first on the list

        self.top_context['generated_files'] = self.generated_files

        # create Jinja template loaders, one loader per output type
        prefix_loader_dict = {}
        for out_format in out_formats:
            prefix_loader_dict[out_format] = jinja2.FileSystemLoader(Path(tpl_dir / out_format))
            prefix_loader_dict[out_format + "_lib"] = jinja2.FileSystemLoader(Path(lib_dir / out_format))
            tpl_loader = jinja2.PrefixLoader(prefix_loader_dict)

        self.jinja2_env = jinja2.Environment(
            loader=tpl_loader,
            autoescape=jinja2.select_autoescape(),
            undefined=jinja2.StrictUndefined,
            line_statement_prefix="--#",
        )

    # =========================================================================
    def get_generated_files(self):
        """Return generated files variable value."""
        return self.generated_files

    # =========================================================================
    def exit_Addrmap(self, node: AddrmapNode):
        """
        Render templates for each address map exit when walking trough address map tree.
        some templates are rnedered only for root address map.
        """

        super().exit_Addrmap(node)

        # formats to generate per address mapp
        if 'vhdl' in self.out_formats:
            if node.get_property('desyrdl_generate_hdl') is None or node.get_property('desyrdl_generate_hdl') is True:
                print(f"VHDL for: {node.inst_name} ({node.type_name})")

                files = self.render_templates(loader="vhdl", outdir="vhdl", context=self.context)
                self.generated_files['vhdl'] = self.generated_files['vhdl'] + files
                self.generated_files["vhdl_dict"][node.inst_name] = files

        if 'adoc' in self.out_formats:
            print(f"ASCIIDOC for: {node.inst_name} ({node.type_name})")
            files = self.render_templates(loader="adoc", outdir="adoc", context=self.context)
            self.generated_files["adoc"] = self.generated_files['adoc'] + files

        # formats to generate on top
        if isinstance(node.parent, RootNode):
            if 'vhdl' in self.out_formats:
                files = self.render_templates(loader="vhdl_lib", outdir="vhdl", context=self.top_context)
                self.generated_files["vhdl"] = files + self.generated_files['vhdl']
                self.generated_files['vhdl_dict']['desyrdl'] = files

            if 'map' in self.out_formats:
                files = self.render_templates(loader="map", outdir="map", context=self.top_context)
                self.generated_files['map'] = self.generated_files['map'] + files

            if 'h' in self.out_formats:
                files = self.render_templates(loader="h", outdir="h", context=self.top_context)
                self.generated_files['h'] = self.generated_files['h'] + files

            if 'cocotb' in self.out_formats:
                files = self.render_templates(loader="cocotb", outdir="cocotb", context=self.top_context)
                self.generated_files['h'] = self.generated_files['cocotb'] + files

            if 'tcl' in self.out_formats:
                files = self.render_templates(loader="tcl", outdir="tcl", context=self.top_context)
                self.generated_files['tcl'] = self.generated_files['tcl'] + files

    # =========================================================================
    def render_templates(self, loader, outdir, context):
        """Render template to outdir using jinja loader and context dictionary."""
        generated_files = []
        # get templates list and theyir ouput from include file
        template = self.jinja2_env.get_template(loader + "/include.txt")
        tpl_list = template.render(context).split()

        # render template list and save in out
        for tplidx in range(0, len(tpl_list), 2):
            # get template
            template = self.jinja2_env.get_template(loader + "/" + tpl_list[tplidx])
            # create out dir if needed
            out_file_path = Path(self.out_dir / outdir / tpl_list[tplidx + 1])
            out_file_path.parents[0].mkdir(parents=True, exist_ok=True)
            # render template and stream it directly to out file
            template.stream(context).dump(str(out_file_path.resolve()))
            # as_posix() ensures forward slashes, also supported by Tcl on Windows,
            # see https://www.tcl.tk/man/tcl8.3/TclCmd/filename.htm#M22
            generated_files.append(out_file_path.as_posix())
            # self.generated_files[outdir].append(outFilePath)
        return generated_files
