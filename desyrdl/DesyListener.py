
# import string
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
    def __init__(self, formatter, templates, out_dir, merge_outputs=False):
        for t,tplstr in templates:
            assert isinstance(t, Path)
        assert isinstance(out_dir, Path)

        self.templates = templates
        self.out_dir = out_dir
        self.generated_files = list()
        self.merge_outputs = merge_outputs

        self.formatter = formatter

        self.init_context()

        # If generated outputs shall be merged, remove any existing files.
        # The output file template string should be the final filename.
        if self.merge_outputs:
            for tpl,tplstr in self.templates:
                try:
                    Path(self.out_dir / tplstr).unlink()
                except FileNotFoundError:
                    pass

    def init_context(self):
        self.regitems = list()
        self.memitems = list()
        self.extitems = list()
        self.regtypes = list()
        self.memtypes = list()
        self.regcount = 0

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

            if self.merge_outputs:
                mode = 'a'
            else:
                mode = 'w'

            with out_path.open(mode) as f_out:
                f_out.write(s_out)
                if out_path not in self.generated_files:
                    self.generated_files.append(out_path)

    def enter_Addrmap(self, node):
        self.regtypes.append(dict())
        self.memtypes.append(dict())
        self.regitems.append(list())
        self.memitems.append(list())
        self.extitems.append(list())

    # types are in the dictionary on the top of the stack
    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes[-1]:
                self.memtypes[-1][node.type_name] = node

        if isinstance(node, RegNode) and not node.external:
            if node.type_name not in self.regtypes[-1]:
                print(f'adding type {node.type_name} to {self.regtypes[-1]}')

                self.regtypes[-1][node.type_name] = node

    def exit_Addrmap(self, node):

        self.regitems[-1].extend(self.gen_regitems(node))
        self.memitems[-1].extend(self.gen_memitems(node))
        self.extitems[-1].extend(self.gen_extitems(node))

        self.context = dict(
                node=node,
                regtypes=[x for x in self.gen_regtypes()],
                memtypes=[x for x in self.gen_memtypes()],
                regitems=self.regitems[-1],
                memitems=self.memitems[-1],
                extitems=self.extitems[-1],
                n_regtypes=len(self.regtypes[-1]),
                n_regitems=len(self.regitems[-1]),
                n_regcount=self.regcount,
                n_memtypes=len(self.memtypes[-1]),
                n_memitems=len(self.memitems[-1]),
                n_extitems=len(self.extitems[-1]))

        # add all non-native explicitly set properties
        for p in node.list_properties(include_native=False):
            assert p not in self.context
            print(f"exit_Addrmap {node.inst_name}: Adding non-native property {p}")
            self.context[p] = node.get_property(p)

        print(f"path_segment = {node.get_path_segment()}")
        print(f"node.inst_name = {node.inst_name}")
        print(f"node.type_name = {node.type_name}")

        # Some context must be cleared on addrmap boundaries
        self.regtypes.pop()
        self.memtypes.pop()
        self.regitems.pop()
        self.memitems.pop()
        self.extitems.pop()
        self.regcount = 0

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

    def gen_regitems(self, node):
        # For indexing of flattened arrays in VHDL port definitions.
        # Move to a dict() or improve VHDL code.
        index = 0

        for i, regx in self.gen_node_names(node, [RegNode], False):

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

            self.regcount += elements

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

    def gen_memitems(self, node):
        for i, memx in self.gen_node_names(node, [MemNode], True, first_only=False):

            context = dict()

            addrmap_segments = memx.get_path_segments(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap = addrmap_segments[-2]
            addrmap_name = ".".join([x for i,x in enumerate(addrmap_segments[-2:])])
            addrmap_full = ".".join([x for i,x in enumerate(addrmap_segments[:-1])])
            addrmap_full_name = ".".join([x for i,x in enumerate(addrmap_segments)])
            addrmap_full_notop = ".".join([x for i,x in enumerate(addrmap_segments[1:-1])])
            addrmap_full_notop_name = ".".join([x for i,x in enumerate(addrmap_segments[1:])])

            context["i"] = i
            context["name"] = memx.type_name
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
            context["vregs"] = [x for x in self.gen_regitems(memx)]

            context["desyrdl_access_channel"] = self.get_access_channel(memx)


            # add all non-native explicitly set properties
            for p in memx.list_properties(include_native=False):
                assert p not in context
                context[p] = memx.get_property(p)

            yield context

    def gen_extitems(self, node):
        for i, extx in self.gen_node_names(node, [AddrmapNode, RegfileNode, RegNode], True, first_only=False):

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

    def gen_regtypes(self):
        for i, regx in enumerate(self.regtypes[-1].values()):
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

    def gen_memtypes(self):
        for i, memx in enumerate(self.memtypes[-1].values()):
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
        pattern = '.*fixed(\d+)'
        srch = re.search(pattern, datatype)
        if srch:
            return int(srch.group(1))
        else:
            return 0

    def get_generated_files(self):
        return self.generated_files


# Types, names and counts are needed. Clear after each exit_Addrmap
class VhdlListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        # generate if no property set or is set to true
        if node.get_property('desyrdl_generate_hdl') is None or \
           node.get_property('desyrdl_generate_hdl') is True:
            self.process_templates(node)


class MapfileListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        self.process_templates(node)
