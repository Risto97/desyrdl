
# import string
import sys
from pathlib import Path  # get filenames

from systemrdl import RDLListener
from systemrdl.node import AddrmapNode  # FieldNode ,AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode


class DesyListener(RDLListener):

    def __init__(self, formatter, tpl, out_dir):
        if not isinstance(tpl, Path):
            print(f"Wrong type passed to {type(self).__name__}")
            sys.exit(1)
        if not isinstance(out_dir, Path):
            print(f"Wrong type passed to {type(self).__name__}")
            sys.exit(1)

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

        s_out = self.formatter.format(s_in, context=self.context)

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
    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes:
                self.memtypes[node.type_name] = node

        if isinstance(node, RegNode) and not node.external:
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node

    def exit_Addrmap(self, node):

        # Only get the immediate children. Otherwise a higher-level AddrmapNode would
        # "see" the arrays of registers/memories below.
        for x in self.gen_node_names(node, RegNode):
            self.regnames.append(x)
        for x in self.gen_node_names(node, MemNode, first_only=False):
            self.memnames.append(x)
        for x in self.gen_ext_names(node, first_only=False):
            self.extnames.append(x)
        self.regcount += self.get_regcount(node, RegNode)

        # what needs to be passed?
        # regtypes: list of RegNodes -> type_name only
        # regnames: longer list of RegNodes -> all inst_names
        # regcount: count of individual registers including those in arrays
        # memtypes: list of MemNodes -> type_name only
        # memnames: longer list of MemNodes -> all inst_names
        self.context = dict(
                node=node,
                regtypes=self.regtypes.values(),
                memtypes=self.memtypes.values(),
                regnames=self.regnames,
                memnames=self.memnames,
                extnames=self.extnames,
                n_regtypes=len(self.regtypes),
                n_regnames=len(self.regnames),
                n_regcount=self.regcount,
                n_memtypes=len(self.memtypes),
                n_memnames=len(self.memnames),
                n_extnames=len(self.extnames))

        print(f"path_segment = {node.get_path_segment()}")
        print(f"node.inst_name = {node.inst_name}")
        print(f"node.type_name = {node.type_name}")

    # yields a tuple (i, node) for each downstream component
    # (Addrmap or external Regfile)
    def gen_ext_names(self, node, first_only=True):
        i = 0
        for child in node.children(unroll=True):
            if isinstance(child, AddrmapNode) or (isinstance(child, RegfileNode) and child.external):
                # if the child is an array, only take
                # the first element, otherwise return
                if child.is_array and first_only is True:
                    if any(k != 0 for k in child.current_idx):
                        continue
                yield (i, child)
                i += 1

    # yields a tuple (i, node) for each child of node that matches type
    def gen_node_names(self, node, type, first_only=True):
        i = 0
        for child in node.children(unroll=True):
            if isinstance(child, type):
                # if the child is an array, only take
                # the first element, otherwise return
                if child.is_array and first_only is True:
                    if any(k != 0 for k in child.current_idx):
                        continue
                yield (i, child)
                i += 1

    def get_regcount(self, node, type):
        i = 0
        for child in node.children(unroll=True):
            # TODO exclude external registers
            if isinstance(child, type):
                # if the child is an array, get its dimensions from the
                # first element
                if child.is_array:
                    if all(k == 0 for k in child.current_idx):
                        p = 1
                        for dim in child.array_dimensions:
                            p *= dim
                        i += p
                else:
                    i += 1
        return i


# Types, names and counts are needed. Clear after each exit_Addrmap
class VhdlListener(DesyListener):

    def exit_Addrmap(self, node):
        super().exit_Addrmap(node)

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
