import os
import sys
import string
from pathlib import Path # get filenames

from systemrdl import RDLCompileError, RDLCompiler, RDLWalker
from systemrdl import RDLListener
from systemrdl.node import RegNode, FieldNode, AddressableNode, AddrmapNode, MemNode, RootNode


class VhdlFormatter(string.Formatter):

#    def __init__(self, top_node):
#        super(VhdlFormatter, self).__init__()
#        top_node = top_node

    def format_field(self, value, spec):
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
            # value signals if it's the last repetition of a {:repeat:}
            # TODO not actually implemented in the format() calls
            if value:
                return ""
            else:
                return ","

        if spec.startswith("repeat"):
            # Expects different types for value depending on what to repeat
            # alternatives:
            # - check isinstance(value, systemrdl.node.RegNode) etc
            # - initialize VhdlFormatter with the root node object and traverse it in here
            what = spec.split(":")[1] # what to repeat?
            # remove "repeat:what:" prefix from spec to obtain the actual template
            template = spec.partition(":")[2].partition(":")[2]
            if what == "regtypes":
                return ''.join([self.format(
                    template,
                    regtype=regtype,
                    name=regtype.type_name)
                    for regtype in value])
            if what == "memtypes":
                return ''.join([self.format(
                    template,
                    memtype=memtype,
                    name=memtype.type_name)
                    for memtype in value])
            elif what == "fields":

                return ''.join([self.format(
                    template,
                    i=i,
                    field=field,
                    hw_we=field.get_property("we"),
                    sw_access=field.get_property("sw").name,
                    hw_access=field.get_property("hw").name,
                    reset=field.get_property("reset"),
                    name=field.type_name)
                    for i,field in enumerate(value.fields())])
            elif what == "regnames":
                #print("repeating regnames with RegNodes in ", value, " and template ", template)
                # value is a list of tuples (i, RegNode)
                return ''.join([self.format(
                    template,
                    i=r[0],
                    reg=r[1],
                    # please don't look at the next two lines. On refactoring I will put it in a dict, promise.
                    N= r[1].array_dimensions[0] if (r[1].is_array and len(r[1].array_dimensions)==2) else 1,
                    M= r[1].array_dimensions[1] if (r[1].is_array and len(r[1].array_dimensions)==2) else r[1].array_dimensions[0] if (r[1].is_array and len(r[1].array_dimensions)==1) else 1)
                    for r in value])
            elif what == "memnames":
                # for..in..if filters the list comprehension
                #memnames = [(i,child) for i,child in enumerate(value.descendants()) if isinstance(child, MemNode)]
                # TODO: use the current node in here instead of filling memnames once for the top node.
                return ''.join([self.format(
                    template,
                    i=m[0],
                    mem=m[1])
                    for m in value])

            else:
                return "-- VOID" # this shouldn't happen
        else:
            return super(VhdlFormatter, self).format_field(value, spec)


# create a dictionary of regtypes:
# - traverse the model
# - check for type RegNode
# - check type, add to dict if not present
class RegtypeListener(RDLListener):

    def __init__(self, regtypes):
        self.regtypes = regtypes

    def enter_Component(self, node):
        if isinstance(node, RegNode):
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node


class MemtypeListener(RDLListener):

    def __init__(self, memtypes):
        self.memtypes = memtypes

    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes:
                self.memtypes[node.type_name] = node


class VhdlListener(RDLListener):

    def __init__(self, memtypes, regtypes):
        self.memtypes = memtypes
        self.mem_cnt  = 0
        self.regtypes = regtypes
        self.reg_cnt  = 0

    def enter_Component(self, node):
        if isinstance(node, MemNode):
            if node.type_name not in self.memtypes:
                self.memtypes[node.type_name] = node

        if isinstance(node, RegNode):
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node


# yields a tuple (i, node) for each child of node that matches type
def gen_node_names(node, type):
    i = 0
    for child in node.children(unroll=True):
        if isinstance(child, type):
            # if the child is an array, only take
            # the first element, otherwise return
            if child.is_array:
                if any(i!=0 for i in child.current_idx):
                    continue
            yield (i, child)
            i += 1

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
        top_node = root

    # no need to unroll arrays since non-homogenous arrays are not supported anyways
    walker = RDLWalker(unroll=True)

    # currently we're collecting register types for each of the AddrmapNodes,
    # not globally
    #regtypes = dict()
    #walker.walk(root, RegtypeListener(regtypes=regtypes))
    #print("".join(["found type of RegNode {}\n".format(x.type_name) for x in regtypes.values()]))

    vf = VhdlFormatter()

    out_dir = Path("HECTARE")
    out_dir.mkdir(exist_ok=True)

    # component type name, either definitive or anonymous: systemrdl.component.Component.type_name
    # The instantiated element is Component.inst_name, right?!

    for node in root.descendants():
        if isinstance(node, AddrmapNode):
            # obtain a dictionary of register and memory types
            regtypes = dict()
            memtypes = dict()
            walker.walk(node, VhdlListener(memtypes=memtypes, regtypes=regtypes))

            # Only get the immediate children. Otherwise a higher-level AddrmapNode would
            # "see" the arrays of registers/memories below.
            regnames = [x for x in gen_node_names(node, RegNode)]
            print([regname[1].inst_name for regname in regnames])
            memnames = [x for x in gen_node_names(node, MemNode)]
            print([memname[1].inst_name for memname in memnames])

            for tpl in Path('./templates').glob('*.vhd.in'):
                with tpl.open('r') as f_in:
                    s_in = f_in.read()
                # creating "views" on dictionaries: d.keys(), d.values() or d.items()
                # modname should be unique wthin the top addrmap so the pkg name is unique, too
                ip_folder_path = ''.join(["modules/", node.type_name, "/hdl"]) # where the user logic lies
                print("ip_folder_path =", ip_folder_path)
                # what needs to be passed?
                # modname: name of each IP module
                # regtypes: list of RegNodes -> type_name only
                # regnames: longer list of RegNodes -> both type_name, inst_name
                # memtypes: list of MemNodes -> type_name only
                # memnames: longer list of MemNodes -> both type_name, inst_name

                # TODO either pass the top_node or a complete dict() similar to Jinja context
                hdl = vf.format(s_in,
                        node=node,
                        modname=node.get_path_segment(),
                        regtypes=regtypes.values(),
                        memtypes=memtypes.values(),
                        regnames=regnames,
                        memnames=memnames,
                        n_regtypes=len(regtypes), # sigh..
                        n_regnames=len(regnames),
                        n_memtypes=len(memtypes),
                        n_memnames=len(memnames))

                suffix = "".join(tpl.suffixes) # get the ".vhd.in"
                out_file = "".join([str(tpl.name).replace(suffix, ""), "_", node.inst_name, ".vhd"])
                out_path = Path(out_dir, out_file)
                print(out_path)
                with out_path.open('w') as f_out:
                    f_out.write(hdl)
                #print(hdl)

if __name__ == '__main__':
    main()
