# import os
import string
import sys
from math import ceil, log2
from pathlib import Path  # get filenames

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker
from systemrdl.node import (AddrmapNode, FieldNode,  # AddressableNode,
                            MemNode, RegfileNode, RegNode, RootNode)


class RdlFormatter(string.Formatter):
    #    def __init__(self, top_node):
    #        super(RdlFormatter, self).__init__()
    #        top_node = top_node

    def context_add_bar(self, context, node):

        # Starting point for finding the top node
        if isinstance(node, AddrmapNode):
            ancestor = node
        else:
            ancestor = node.parent

        # ancestor might be the top node already, so check for that
        if not isinstance(ancestor.parent, RootNode):
            while not isinstance(ancestor.parent.parent, RootNode):
                ancestor = ancestor.parent

        try:
            bar = ancestor.get_property("BAR")
            print(f"{node.inst_name} gets BAR {bar} from {ancestor.inst_name}")
        except LookupError:
            # handle standalone modules in a temporary way
            bar = 0
            pass
        finally:
            bar_start = ancestor.absolute_address


        context["bar"] = bar
        context["baraddr"] = node.absolute_address-bar_start

    def format_field(self, value, spec):

        if spec.startswith("ifgtzero"):
            (checkme, colon, foo) = spec.partition(":")
            (target, colon, template) = foo.partition(":")
            if checkme != "ifgtzero":
                raise Exception("Template function ifgtzero detected but the spec seems to be broken")

            if value[target] > 0:
                return self.format(template, context=value)
            else:
                return ""

        if spec == "ftype" and isinstance(value, FieldNode):
            # Expects FieldNode type as value
            if value.get_property("counter"):
                return "COUNTER"
            elif value.get_property("intr"):
                return "INTERRUPT"
            elif value.implements_storage:
                return "STORAGE"
            elif not value.is_virtual:
                return "WIRE"
            else:
                # error (TODO: handle as such)
                print("error: can't make out the type of field for {}".format(value.get_path()))
                return "WIRE"

        if spec == "comma":
            # 'value' signals if it's the last repetition of a {:repeat:}
            # TODO unfinished, not actually implemented in the format() calls
            if value:
                return ""
            else:
                return ","

        if spec == "upper":
            return value.upper()

        if spec == "lower":
            return value.lower()

        if spec.startswith("repeat"):
            # Expects different types for value depending on what to repeat
            # alternatives:
            # - check isinstance(value, systemrdl.node.RegNode) etc
            # - initialize RdlFormatter with the root node object and traverse it in here
            what = spec.split(":")[1]  # what to repeat?
            # remove "repeat:what:" prefix from spec to obtain the actual template
            template = spec.partition(":")[2].partition(":")[2]
            if what == "regtypes":
                results = []
                for i, regtype in enumerate(value[what]):
                    x = [i,regtype]

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["i"] = x[0]
                    newc["regtype"] = x[1]
                    newc["fields"] = [[i,f] for i,f in  enumerate(x[1].fields())]

                    # format the template
                    results.append(self.format(template, **newc))

                return "".join(results)

            if what == "memtypes":
                results = []

                for x in value[what]:

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["mem"] = x
                    newc["mementries"] = x.get_property("mementries")
                    newc["memwidth"] = x.get_property("memwidth")
                    newc["addresses"] = x.get_property("mementries") * 4
                    newc["aw"] = ceil(log2(x.get_property("mementries") * 4))

                    # format the template
                    results.append(self.format(template, **newc))

                # for..in..if filters the list comprehension
                # memnames = [(i,child) for i,child in enumerate(value.descendants()) if isinstance(child, MemNode)]
                # TODO: use the current node in here instead of filling memnames once for the top node.
                return "".join(results)

            elif what == "fields":
                results = []

                for x in value:

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["i"] = x[0]
                    newc["regtype"] = x[1].parent
                    newc["field"] = x[1]
                    newc["hw_we"] = x[1].get_property("we")
                    newc["sw_access"] = x[1].get_property("sw").name
                    newc["hw_access"] = x[1].get_property("hw").name
                    newc["reset"] = 0 if x[1].get_property("reset") is None else x[1].get_property("reset")
                    newc["decrwidth"] = x[1].get_property("decrwidth") if x[1].get_property("decrwidth") is not None else 1
                    newc["incrwidth"] = x[1].get_property("incrwidth") if x[1].get_property("incrwidth") is not None else 1
                    newc["name"] = x[1].type_name

                    results.append(self.format(template, **newc))

                return "".join(results)

            elif what == "regnames":
                results = []

                # For indexing of flattened arrays in VHDL port definitions.
                # Move to a dict() or improve VHDL code.
                base = 0

                for x in value[what]:
                    if x[1].parent.is_array:
                        addrmap = f"{x[1].parent.inst_name}.{x[1].parent.current_idx}"
                    else:
                        addrmap = f"{x[1].parent.inst_name}.0"

                    N = 1
                    M = 1
                    if x[1].is_array:
                        if len(x[1].array_dimensions) == 2:
                            N = x[1].array_dimensions[0]
                            M = x[1].array_dimensions[1]
                        else:
                            N = 1
                            if len(x[1].array_dimensions) == 1:
                                M = x[1].array_dimensions[0]
                            else:
                                M = 1

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["i"] = x[0]
                    newc["addrmap"] = addrmap
                    newc["reladdr"] = x[1].address_offset
                    newc["absaddr"] = x[1].absolute_address

                    newc["reg"] = x[1]
                    newc["N"] = N
                    newc["M"] = M
                    newc["rw"] = "RW" if x[1].has_sw_writable else "RO"
                    newc["regwidth"] = x[1].get_property("regwidth")
                    # "base" is needed for indexing of flattened arrays in VHDL
                    # port definitions. Improve VHDL code to get rid of it.
                    newc["base"] = base
                    base = base+N*M

                    # custom context
                    self.context_add_bar(newc, x[1])

                    # format the template
                    results.append(self.format(template, **newc))

                return "".join(results)

            elif what == "memnames":
                results = []

                for x in value[what]:
                    if x[1].parent.is_array:
                        addrmap = f"{x[1].parent.inst_name}.{x[1].parent.current_idx}"
                    else:
                        addrmap = f"{x[1].parent.inst_name}.0"

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["i"] = x[0]
                    newc["addrmap"] = addrmap
                    newc["reladdr"] = x[1].address_offset
                    newc["absaddr"] = x[1].absolute_address

                    newc["mem"] = x[1]
                    newc["mementries"] = x[1].get_property("mementries")
                    newc["memwidth"] = x[1].get_property("memwidth")
                    newc["addresses"] = x[1].get_property("mementries") * 4
                    newc["aw"] = ceil(log2(x[1].get_property("mementries") * 4))

                    # custom context
                    self.context_add_bar(newc, x[1])

                    # format the template
                    results.append(self.format(template, **newc))

                # for..in..if filters the list comprehension
                # memnames = [(i,child) for i,child in enumerate(value.descendants()) if isinstance(child, MemNode)]
                # TODO: use the current node in here instead of filling memnames once for the top node.
                return "".join(results)

            elif what == "extnames":
                results = []

                for x in value[what]:
                    if x[1].parent.is_array:
                        addrmap = f"{x[1].parent.inst_name}.{x[1].parent.current_idx}"
                    else:
                        addrmap = f"{x[1].parent.inst_name}.0"

                    # prevent bugs by putting new data in a separate copy per
                    # iteration
                    # newc = value.copy()
                    newc = dict()

                    newc["i"] = x[0]
                    newc["addrmap"] = addrmap
                    newc["reladdr"] = x[1].address_offset
                    newc["absaddr"] = x[1].absolute_address

                    newc["ext"] = x[1]
                    newc["total_words"] = int(x[1].total_size/4)
                    newc["aw"] = ceil(log2(x[1].size))

                    # custom context
                    self.context_add_bar(newc, x[1])

                    # format the template
                    results.append(self.format(template, **newc))

                return "".join(results)

            else:
                return "-- VOID"  # this shouldn't happen
        else:
            return super(RdlFormatter, self).format_field(value, spec)


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


def main():
    rdlfiles = sys.argv[1:]

    # Create an instance of the compiler
    rdlc = RDLCompiler()

    try:
        for rdlfile in rdlfiles:
            rdlc.compile_file(rdlfile)
        root = rdlc.elaborate()
    except RDLCompileError:
        # A compilation error occurred. Exit with error code
        sys.exit(1)
    if isinstance(root, RootNode):
        top_node = root.top
    else:
        #top_node = root
        raise Error("root is not a RootNode")

    vf = RdlFormatter()

    out_dir = Path("HECTARE")
    out_dir.mkdir(exist_ok=True)

    basedir = Path(__file__).parent.absolute()
    tpldir = basedir / "templates"
    for tpl in tpldir.glob('*.in'):
        listener = AddrmapListener(vf, tpl, out_dir)
        tpl_walker = RDLWalker(unroll=True)
        tpl_walker.walk(top_node, listener)

if __name__ == '__main__':
    main()
