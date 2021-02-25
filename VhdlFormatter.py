import os
import sys
import string
from pathlib import Path # get filenames
from math import ceil, log2

from systemrdl import RDLCompileError, RDLCompiler, RDLWalker
from systemrdl import RDLListener
from systemrdl.node import RegNode, RegfileNode, FieldNode, AddressableNode, AddrmapNode, MemNode, RootNode

from peakrdl.html import HTMLExporter

class VhdlFormatter(string.Formatter):

#    def __init__(self, top_node):
#        super(VhdlFormatter, self).__init__()
#        top_node = top_node

    # the 'reset' property of a field can be 'None'
    def parse_reset(self, reset, width):
        if reset == None:
            #return ''.join(['"', '0'*width, '"'])
            return "(32-1 downto 0 => '0')"
        else:
            return "std_logic_vector(to_signed({reset}, {width}))".format(reset=reset, width=32)

    def format_field(self, value, spec):
        if spec.startswith("ifgtzero"):
            (checkme,colon,foo) = spec.partition(":")
            (target,colon,template) = foo.partition(":")
            if checkme != "ifgtzero":
                raise Exception("Template function ifgtzero detected but the spec seems to be broken")

            if value[target] > 0:
                return self.format(template, value)
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
            # value signals if it's the last repetition of a {:repeat:}
            # TODO not actually implemented in the format() calls
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
            # - initialize VhdlFormatter with the root node object and traverse it in here
            what = spec.split(":")[1] # what to repeat?
            # remove "repeat:what:" prefix from spec to obtain the actual template
            template = spec.partition(":")[2].partition(":")[2]
            if what == "regtypes":
                return ''.join([self.format(
                    template,
                    i=i,
                    regtype=regtype,
                    name=regtype.type_name)
                    for i,regtype in enumerate(value[what])])
            if what == "memtypes":
                return ''.join([self.format(
                    template,
                    i=i,
                    memtype=memtype,
                    name=memtype.type_name)
                    for i,memtype in enumerate(value[what])])
            elif what == "fields":

                return ''.join([self.format(
                    template,
                    i=i,
                    field=field,
                    hw_we=field.get_property("we"),
                    sw_access=field.get_property("sw").name,
                    hw_access=field.get_property("hw").name,
                    reset=self.parse_reset(field.get_property("reset"), field.width),
                    decrwidth=field.get_property("decrwidth") if (field.get_property("decrwidth") != None) else 1,
                    incrwidth=field.get_property("incrwidth") if (field.get_property("incrwidth") != None) else 1,
                    name=field.type_name)
                    for i,field in enumerate(value[what].fields())])
            elif what == "regnames":
                #print("repeating regnames with RegNodes in ", value, " and template ", template)
                # value is a list of tuples (i, RegNode)

                # For indexing of flattened arrays in VHDL port definitions.
                # Move to a dict() or improve VHDL code.
                base = [0]
                for i,x in enumerate(value[what]):
                    N = x[1].array_dimensions[0] if (x[1].is_array and len(x[1].array_dimensions)==2) else 1
                    M = x[1].array_dimensions[1] if (x[1].is_array and len(x[1].array_dimensions)==2) else x[1].array_dimensions[0] if (x[1].is_array and len(x[1].array_dimensions)==1) else 1
                    base.append(base[i]+N*M)

                addrmap = []
                bar = []
                baraddr = []
                for x in value[what]:
                    if x[1].owning_addrmap.is_array:
                        addrmap.append(f"{x[1].owning_addrmap.inst_name}.{x[1].owning_addrmap.current_idx}")
                    else:
                        addrmap.append(f"{x[1].owning_addrmap.inst_name}.0")

                    parent = x[1].parent
                    while parent.get_property("BAR") == None:
                        parent = parent.parent
                    bar.append(parent.get_property("BAR"))
                    baraddr.append(parent.absolute_address)

                # format the template
                return ''.join([self.format(
                    template,
                    i=r[0],
                    base=base[r[0]],
                    reg=r[1],
                    # please don't look at the next two lines. On refactoring I will put it in a dict, promise.
                    N= r[1].array_dimensions[0] if (r[1].is_array and len(r[1].array_dimensions)==2) else 1,
                    M= r[1].array_dimensions[1] if (r[1].is_array and len(r[1].array_dimensions)==2) else r[1].array_dimensions[0] if (r[1].is_array and len(r[1].array_dimensions)==1) else 1,
                    rw = "RW" if r[1].has_sw_writable else "RO",
                    regwidth = r[1].get_property("regwidth"),
                    addrmap = addrmap[r[0]],
                    addr = r[1].absolute_address-baraddr[r[0]],
                    bar = bar[r[0]])
                    for r in value[what]])
            elif what == "memnames":
                addrmap = []
                bar = []
                baraddr = []
                for x in value[what]:
                    if x[1].is_array:
                        addrmap.append(f"{x[1].owning_addrmap.inst_name}.{x[1].owning_addrmap.current_idx}")
                    else:
                        addrmap.append(f"{x[1].owning_addrmap.inst_name}.0")

                    parent = x[1].parent
                    while parent.get_property("BAR") == None:
                        parent = parent.parent
                    bar.append(parent.get_property("BAR"))
                    baraddr.append(parent.absolute_address)

                # for..in..if filters the list comprehension
                #memnames = [(i,child) for i,child in enumerate(value.descendants()) if isinstance(child, MemNode)]
                # TODO: use the current node in here instead of filling memnames once for the top node.
                return ''.join([self.format(
                    template,
                    i=m[0],
                    mem=m[1],
                    mementries = m[1].get_property("mementries"),
                    memwidth = m[1].get_property("memwidth"),
                    addresses = m[1].get_property("mementries") * 4,
                    aw = ceil(log2(m[1].get_property("mementries") * 4)),
                    addrmap = addrmap[m[0]],
                    addr = m[1].absolute_address-baraddr[m[0]],
                    bar = bar[m[0]])
                    for m in value[what]])
            elif what == "extnames":
                addrmap = []
                bar = []
                baraddr = []
                for x in value[what]:
                    if isinstance(x[1], AddrmapNode):
                        if x[1].is_array:
                            addrmap.append(f"{x[1].owning_addrmap.inst_name}.{x[1].owning_addrmap.current_idx}")
                        else:
                            addrmap.append(f"{x[1].owning_addrmap.inst_name}.0")
                        parent = x[1]
                    else:
                        if x[1].is_array:
                            addrmap.append(f"{x[1].parent.inst_name}.{x[1].owning_addrmap.current_idx}")
                        else:
                            addrmap.append(f"{x[1].parent.inst_name}.0")
                        parent = x[1].parent

                    while parent.get_property("BAR") == None:
                        parent = parent.parent
                    bar.append(parent.get_property("BAR"))
                    baraddr.append(parent.absolute_address)

                return ''.join([self.format(
                    template,
                    i=ext[0],
                    ext=ext[1],
                    total_words = int(ext[1].total_size/4),
                    aw = ceil(log2(ext[1].size)),
                    addrmap = addrmap[ext[0]],
                    addr = ext[1].absolute_address-baraddr[ext[0]],
                    bar = bar[ext[0]])
                    for ext in value[what]])
            elif what == "addrmaps":
                addrmap = []
                bar = []
                baraddr = []
                for x in value[what]:
                    if x[1].is_array:
                        addrmap.append(f"{x[1].parent.inst_name}.{x[1].owning_addrmap.current_idx}")
                    else:
                        addrmap.append(f"{x[1].parent.inst_name}.0")

                    parent = x[1]
                    while parent.get_property("BAR") == None:
                        parent = parent.parent
                    bar.append(parent.get_property("BAR"))
                    baraddr.append(parent.absolute_address)

                return ''.join([self.format(
                    template,
                    i=x[0],
                    x=x[1],
                    total_words = int(x[1].total_size/4),
                    addrmap = addrmap[x[0]],
                    addr = x[1].absolute_address-baraddr[x[0]],
                    bar = bar[x[0]])
                    for x in value[what]])

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

        if isinstance(node, RegNode) and not node.external:
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node


# yields a tuple (i, node) for each downstream component
# (Addrmap or external Regfile)
def gen_ext_names(node, first_only=True):
    i = 0
    for child in node.children(unroll=True):
        if isinstance(child, AddrmapNode) or (isinstance(child, RegfileNode) and child.external):
            # if the child is an array, only take
            # the first element, otherwise return
            if child.is_array and first_only==True:
                if any(k!=0 for k in child.current_idx):
                    continue
            yield (i, child)
            i += 1

# yields a tuple (i, node) for each child of node that matches type
def gen_node_names(node, type, first_only=True):
    i = 0
    for child in node.children(unroll=True):
        if isinstance(child, type):
            # if the child is an array, only take
            # the first element, otherwise return
            if child.is_array and first_only==True:
                if any(k!=0 for k in child.current_idx):
                    continue
            yield (i, child)
            i += 1

def get_regcount(node, type):
    i = 0
    for child in node.children(unroll=True):
        # TODO exclude external registers
        if isinstance(child, type):
            # if the child is an array, get its dimensions from the
            # first element
            if child.is_array:
                if all(k==0 for k in child.current_idx):
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

    exporter = HTMLExporter()
    exporter.export(root, str(out_dir))

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
            memnames = [x for x in gen_node_names(node, MemNode, first_only=False)]
            print([memname[1].inst_name for memname in memnames])
            extnames = [x for x in gen_ext_names(node, first_only=False)]
            #print([extname[1].inst_name for extname in extnames])
            print([extname for extname in extnames])
            addrmaps = [x for x in gen_node_names(node, AddrmapNode, first_only=False)]
            regcount = get_regcount(node, RegNode)
            print("regcount = {}".format(regcount))

            basedir = Path(__file__).parent.absolute()
            tpldir = basedir / "templates"
            for tpl in tpldir.glob('*.in'):
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
                # registers: count of individual registers including those in arrays
                # memtypes: list of MemNodes -> type_name only
                # memnames: longer list of MemNodes -> both type_name, inst_name
                context = dict(
                        node=node,
                        regtypes=regtypes.values(),
                        memtypes=memtypes.values(),
                        regnames=regnames,
                        memnames=memnames,
                        extnames=extnames,
                        addrmaps=addrmaps,
                        n_regtypes=len(regtypes), # sigh..
                        n_regnames=len(regnames),
                        n_regcount=regcount,
                        n_memtypes=len(memtypes),
                        n_memnames=len(memnames),
                        n_extnames=len(extnames))

                print(f"modname = {node.get_path_segment()}")
                print(f"node.inst_name = {node.inst_name}")

                suffix = "".join(tpl.suffixes) # get the ".vhd.in"
                out_file = "".join([str(tpl.name).replace(suffix, ""), "_", node.inst_name, suffix[:-3]])
                out_path = Path(out_dir, out_file)
                print(out_path)

                hdl = vf.format(s_in, context=context, modname=node.get_path_segment())

                with out_path.open('w') as f_out:
                    f_out.write(hdl)
                #print(hdl)

if __name__ == '__main__':
    main()
