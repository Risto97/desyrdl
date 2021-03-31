import string
import sys
from pathlib import Path  # get filenames

from systemrdl import RDLListener
from systemrdl.node import AddrmapNode, FieldNode  #, AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode


class AddrmapListener(RDLListener):

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

        # For each AddrmapNode a dictionary of register and memory types must
        # be filled and then cleared again on exit_Addrmap
        self.regtypes = dict()
        self.memtypes = dict()
        self.mem_cnt  = 0
        self.reg_cnt  = 0

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
        regnames = [x for x in self.gen_node_names(node, RegNode)]
        print([regname[1].inst_name for regname in regnames])
        memnames = [x for x in self.gen_node_names(node, MemNode, first_only=False)]
        print([memname[1].inst_name for memname in memnames])
        extnames = [x for x in self.gen_ext_names(node, first_only=False)]
        print([extname[1].inst_name for extname in extnames])
        #print([extname for extname in extnames])
        regcount = self.get_regcount(node, RegNode)
        print("regcount = {}".format(regcount))

        # what needs to be passed?
        # FIXME Some of this could be done in a RdlFormatter.format() function
        # regtypes: list of RegNodes -> type_name only
        # regnames: longer list of RegNodes -> all inst_names
        # regcount: count of individual registers including those in arrays
        # memtypes: list of MemNodes -> type_name only
        # memnames: longer list of MemNodes -> all inst_names
        context = dict(
                node=node,
                regtypes=self.regtypes.values(),
                memtypes=self.memtypes.values(),
                regnames=regnames,
                memnames=memnames,
                extnames=extnames,
                n_regtypes=len(self.regtypes),
                n_regnames=len(regnames),
                n_regcount=regcount,
                n_memtypes=len(self.memtypes),
                n_memnames=len(memnames),
                n_extnames=len(extnames))

        print(f"path_segment = {node.get_path_segment()}")
        print(f"node.inst_name = {node.inst_name}")
        print(f"node.type_name = {node.type_name}")

        # TODO this is for the future
        # creating "views" on dictionaries: d.keys(), d.values() or d.items()
        ip_folder_path = ''.join(["modules/", node.type_name, "/hdl"])  # where the user logic lies
        print("ip_folder_path =", ip_folder_path)

        with self.tpl.open('r') as f_in:
            s_in = f_in.read()

        hdl = self.formatter.format(s_in, context=context)

        suffix = "".join(self.tpl.suffixes)  # get the ".vhd.in"

        # FIXME not so clean
        out_file = "".join([str(self.tpl.name).replace(suffix, ""), "_", node.type_name, suffix[:-3]])
        out_path = Path(self.out_dir, out_file)
        print(out_path)
        if out_path.is_file():
            # two possible reasons:
            # (1) old output from previous run
            # (2) this is another AddrmapNode instance of the same type
            # For now we just overwrite existing files
            print("File exists, overwriting: {}".format(out_path))

        with out_path.open('w') as f_out:
            f_out.write(hdl)

        self.regtypes = dict()
        self.memtypes = dict()
        self.mem_cnt  = 0
        self.reg_cnt  = 0

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
