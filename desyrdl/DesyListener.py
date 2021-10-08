
# import string
# import sys
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
        self.regnames = list()
        self.memnames = list()
        self.extnames = list()
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
        self.regnames.append(list())
        self.memnames.append(list())
        self.extnames.append(list())

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

        self.regnames[-1].extend(self.gen_regnames(node))
        self.memnames[-1].extend(self.gen_memnames(node))
        self.extnames[-1].extend(self.gen_extnames(node))

        self.regcount += len([x for x in self.gen_node_names(node, [RegNode], False)])

        self.context = dict(
                node=node,
                regtypes=[x for x in self.gen_regtypes()],
                memtypes=[x for x in self.gen_memtypes()],
                regnames=self.regnames[-1],
                memnames=self.memnames[-1],
                extnames=self.extnames[-1],
                n_regtypes=len(self.regtypes[-1]),
                n_regnames=len(self.regnames[-1]),
                n_regcount=self.regcount,
                n_memtypes=len(self.memtypes[-1]),
                n_memnames=len(self.memnames[-1]),
                n_extnames=len(self.extnames[-1]))

        # add all non-native explicitly set properties
        for p in node.list_properties(include_native=False):
            assert not p in self.context
            print(f"exit_Addrmap {node.inst_name}: Adding non-native property {p}")
            self.context[p] = node.get_property(p)

        print(f"path_segment = {node.get_path_segment()}")
        print(f"node.inst_name = {node.inst_name}")
        print(f"node.type_name = {node.type_name}")

        # Some context must be cleared on addrmap boundaries
        self.regtypes.pop()
        self.memtypes.pop()
        self.regnames.pop()
        self.memnames.pop()
        self.extnames.pop()
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

    def gen_regnames(self, node):
        # For indexing of flattened arrays in VHDL port definitions.
        # Move to a dict() or improve VHDL code.
        internal_offset = 0

        for i,x in self.gen_node_names(node, [RegNode], False):

            N = 1
            M = 1
            if x.is_array:
                if len(x.array_dimensions) == 2:
                    N = x.array_dimensions[0]
                    M = x.array_dimensions[1]
                else:
                    N = 1
                    if len(x.array_dimensions) == 1:
                        M = x.array_dimensions[0]
                    else:
                        M = 1

            context = dict()

            addrmap = x.owning_addrmap.get_path_segment(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap_full = x.owning_addrmap.get_path(array_suffix='.{index:d}', empty_array_suffix='')

            context["i"] = i
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["reladdr"] = x.address_offset
            context["absaddr"] = x.absolute_address

            context["reg"] = x
            context["N"] = N
            context["M"] = M
            context["rw"] = "RW" if x.has_sw_writable else "RO"
            context["regwidth"] = x.get_property("regwidth")
            # "internal_offset" is needed for indexing of flattened arrays in VHDL
            # port definitions. Improve VHDL code to get rid of it.
            context["internal_offset"] = internal_offset
            internal_offset = internal_offset+N*M

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                assert not p in context
                context[p] = x.get_property(p)

            yield context

    def gen_memnames(self, node):
        for i,x in self.gen_node_names(node, [MemNode], True, first_only=False):

            context = dict()

            addrmap = x.owning_addrmap.get_path_segment(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap_full = x.owning_addrmap.get_path(array_suffix='.{index:d}', empty_array_suffix='')

            context["i"] = i
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["reladdr"] = x.address_offset
            context["absaddr"] = x.absolute_address

            context["mem"] = x
            context["mementries"] = x.get_property("mementries")
            context["memwidth"] = x.get_property("memwidth")
            context["addresses"] = x.get_property("mementries") * 4
            context["aw"] = ceil(log2(x.get_property("mementries") * 4))

            # virtual registers, e.g. for DMA regions
            context["vregs"] = [x for x in self.gen_regnames(x)]

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                assert not p in context
                context[p] = x.get_property(p)

            yield context

    def gen_extnames(self, node):
        for i,x in self.gen_node_names(node, [AddrmapNode, RegfileNode, RegNode], True, first_only=False):

            context = dict()

            addrmap = x.parent.get_path_segment(array_suffix='.{index:d}', empty_array_suffix='')
            addrmap_full = x.parent.get_path(array_suffix='.{index:d}', empty_array_suffix='')

            context["i"] = i
            context["addrmap"] = addrmap
            context["addrmap_full"] = addrmap_full
            context["reladdr"] = x.address_offset
            context["absaddr"] = x.absolute_address

            context["ext"] = x
            context["total_words"] = int(x.total_size/4)
            context["aw"] = ceil(log2(x.size))

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                if not p in context:
                    context[p] = x.get_property(p)

            yield context

    def gen_regtypes(self):
        for i,x in enumerate(self.regtypes[-1].values()):
            context = dict()

            context["i"] = i
            context["regtype"] = x
            context["fields"] = [f for f in self.gen_fields(x)]

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                assert not p in context
                context[p] = x.get_property(p)

            yield context

    def gen_memtypes(self):
        for i,x in enumerate(self.memtypes[-1].values()):
            context = dict()

            context["mem"] = x
            context["mementries"] = x.get_property("mementries")
            context["memwidth"] = x.get_property("memwidth")
            context["addresses"] = x.get_property("mementries") * 4
            context["aw"] = ceil(log2(x.get_property("mementries") * 4))

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                assert not p in context
                context[p] = x.get_property(p)

            yield context

    def gen_fields(self, node):
        for i,x in enumerate(node.fields()):

            context = dict()

            context["i"] = i
            context["regtype"] = x.parent
            context["field"] = x
            context["ftype"] = self.get_ftype(x)
            context["hw_we"] = x.get_property("we")
            context["sw_access"] = x.get_property("sw").name
            context["hw_access"] = x.get_property("hw").name
            context["reset"] = 0 if x.get_property("reset") is None else x.get_property("reset")
            context["decrwidth"] = x.get_property("decrwidth") if x.get_property("decrwidth") is not None else 1
            context["incrwidth"] = x.get_property("incrwidth") if x.get_property("incrwidth") is not None else 1
            context["name"] = x.type_name

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in node.list_properties(include_native=False):
                assert not p in context
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
            print("error: can't make out the type of field for {}".format(node.get_path()))
            return "WIRE"

    def get_access_channel(self, node):

        # Starting point for finding the top node
        ancestor = node.owning_addrmap

        while not isinstance(ancestor.parent, RootNode):
            ancestor = ancestor.parent
        assert isinstance(ancestor.parent, RootNode)

        try:
            ch = ancestor.get_property("desyrdl_access_channel")
        except LookupError:
            # handle standalone modules in a temporary way
            ch = 0
            print(f"Couldn't find access channel, setting {ch}")
            pass

        return ch

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
