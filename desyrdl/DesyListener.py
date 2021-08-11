
# import string
import sys
from pathlib import Path  # get filenames
from math import ceil, log2

from systemrdl import RDLListener
from systemrdl.node import AddrmapNode, FieldNode # ,AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode


class DesyListener(RDLListener):

    def __init__(self, formatter, tpl, out_dir):
        assert isinstance(tpl, Path)
        assert isinstance(out_dir, Path)

        self.tpl = tpl
        self.out_dir = out_dir

        self.formatter = formatter

        self.init_context()

    def init_context(self):
        self.regnames = list()
        self.memnames = list()
        self.extnames = list()
        self.regtypes = dict()
        self.memtypes = dict()
        self.regcount = 0

    def process_template(self, node):
        with self.tpl.open('r') as f_in:
            s_in = f_in.read()

        s_out = self.formatter.format(s_in, **self.context)

        suffix = "".join(self.tpl.suffixes)  # get the ".vhd.in"

        # FIXME not so clean
        out_file = "".join([str(self.tpl.name).replace(suffix, ""), "_", node.type_name, suffix[:-3]])
        out_path = Path(self.out_dir, out_file)
        print('Output file: ' + str(out_path))
        if out_path.is_file():
            # two possible reasons:
            # (1) old output from previous run
            # (2) this is another AddrmapNode instance of the same type
            # For now we just overwrite existing files
            print("File exists, overwriting: {}".format(out_path))

        with out_path.open('w') as f_out:
            f_out.write(s_out)

    # types
    # TODO might have to be cleared on enter_Addrmap
    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes:
                self.memtypes[node.type_name] = node

        if isinstance(node, RegNode) and not node.external:
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node

    def exit_Addrmap(self, node):

        # Each address map adds to the list of addressable nodes. This is used
        # for mapfile generation only - for HDL generation the list gets
        # cleared after being used.

        #self.regnames[len(self.regnames):] = [x for x in self.gen_regnames(node)]
        #self.memnames[len(self.memnames):] = [x for x in self.gen_memnames(node)]
        #self.extnames[len(self.extnames):] = [x for x in self.gen_extnames(node)]
        # python is nice, use list.extend(iterable)
        self.regnames.extend(self.gen_regnames(node))
        self.memnames.extend(self.gen_memnames(node))
        self.extnames.extend(self.gen_extnames(node))

        self.regcount += len([x for x in self.gen_node_names(node, [RegNode], False)])

        self.context = dict(
                node=node,
                regtypes=[x for x in self.gen_regtypes()],
                memtypes=[x for x in self.gen_memtypes()],
                regnames=self.regnames,
                memnames=self.memnames,
                extnames=self.extnames,
                n_regtypes=len(self.regtypes),
                n_regnames=len(self.regnames),
                n_regcount=self.regcount,
                n_memtypes=len(self.memtypes),
                n_memnames=len(self.memnames),
                n_extnames=len(self.extnames))

        # add all non-native explicitly set properties
        for p in node.list_properties(include_native=False):
            assert not p in self.context
            print(f"exit_Addrmap {node.inst_name}: Adding non-native property {p}")
            self.context[p] = node.get_property(p)

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

    def gen_regnames(self, node):
        # For indexing of flattened arrays in VHDL port definitions.
        # Move to a dict() or improve VHDL code.
        base = 0

        for i,x in self.gen_node_names(node, [RegNode], False):
            if x.parent.is_array:
                addrmap = f"{x.parent.inst_name}.{x.parent.current_idx}"
            else:
                addrmap = f"{x.parent.inst_name}.0"

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

            context["i"] = i
            context["addrmap"] = addrmap
            context["reladdr"] = x.address_offset
            context["absaddr"] = x.absolute_address

            context["reg"] = x
            context["N"] = N
            context["M"] = M
            context["rw"] = "RW" if x.has_sw_writable else "RO"
            context["regwidth"] = x.get_property("regwidth")
            # "base" is needed for indexing of flattened arrays in VHDL
            # port definitions. Improve VHDL code to get rid of it.
            context["base"] = base
            base = base+N*M

            context["desyrdl_access_channel"] = self.get_access_channel(x)

            # add all non-native explicitly set properties
            for p in x.list_properties(include_native=False):
                assert not p in context
                context[p] = x.get_property(p)

            yield context

    def gen_memnames(self, node):
        for i,x in self.gen_node_names(node, [MemNode], True, first_only=False):
            if x.parent.is_array:
                addrmap = f"{x.parent.inst_name}.{x.parent.current_idx}"
            else:
                addrmap = f"{x.parent.inst_name}.0"

            context = dict()

            context["i"] = i
            context["addrmap"] = addrmap
            context["reladdr"] = x.address_offset
            context["absaddr"] = x.absolute_address

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

    def gen_extnames(self, node):
        for i,x in self.gen_node_names(node, [AddrmapNode, RegfileNode, RegNode], True, first_only=False):
            if x.parent.is_array:
                addrmap = f"{x.parent.inst_name}.{x.parent.current_idx}"
            else:
                addrmap = f"{x.parent.inst_name}.0"

            context = dict()

            context["i"] = i
            context["addrmap"] = addrmap
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
        for i,x in enumerate(self.regtypes.values()):
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
        for i,x in enumerate(self.memtypes.values()):
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


# Types, names and counts are needed. Clear after each exit_Addrmap
class VhdlListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        # only generate something if the custom property is set
        if node.get_property('desyrdl_generate_hdl'):
            self.process_template(node)

        # Context must be cleared on addrmap boundaries
        self.init_context()


# Names are needed. Collect until exiting the top Addrmap
class MapfileListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

        # only handle the top Addrmap, otherwise do nothing
        if isinstance(node.parent, RootNode):
            self.process_template(node)
