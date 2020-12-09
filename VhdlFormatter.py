import os
import sys
import string

from systemrdl import RDLCompileError, RDLCompiler, RDLWalker
from systemrdl import RDLListener
from systemrdl.node import RegNode, FieldNode, AddressableNode


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
                    name=regtype.get_property("name"))
                    for regtype in value])
            elif what == "fields":

                return ''.join([self.format(
                    template,
                    i=i,
                    field=field,
                    hw_we=field.get_property("we"),
                    sw_access=field.get_property("sw").name,
                    hw_access=field.get_property("hw").name,
                    reset=field.get_property("reset"),
                    name=field.get_property("name"))
                    for i,field in enumerate(value.fields())])
            else:
                return "-- VOID" # this shouldn't happen
        else:
            return super(VhdlFormatter, self).format_field(value, spec)


# create a dictionary of regtypes:
# - traverse the model
# - check for tyoe RegNode
# - check type, add to dict if not present
class RegtypeListener(RDLListener):

    def __init__(self, regtypes):
        self.regtypes = regtypes

    def enter_Component(self, node):
        if isinstance(node, RegNode):
            #print("Entering RegNode of type {}".format(node.type_name))
            if node.type_name not in self.regtypes:
                self.regtypes[node.type_name] = node



def main():
    rdlfile = sys.argv[1]

    # Create an instance of the compiler
    rdlc = RDLCompiler()

    try:
        rdlc.compile_file(rdlfile)
        root = rdlc.elaborate()
    except RDLCompileError:
        # A compilation error occurred. Exit with error code
        sys.exit(1)
    top_node = root.get_child_by_name("top")

    # creating "views" on dictionaries: d.keys(), d.values(), d.items()
    regtypes = dict()
    walker = RDLWalker(unroll=True)
    walker.walk(root, RegtypeListener(regtypes=regtypes))
    #print("".join(["found type of RegNode {}\n".format(x.type_name) for x in regtypes.values()]))

    vf = VhdlFormatter()

    filename = 'templates/minimal.vhd.in'

    with open(filename, 'r') as f_in:
        s_in = f_in.read()
    with open(filename.rpartition('.')[0], 'w') as f_out:
        hdl = vf.format(s_in, regtypes=regtypes.values())
        f_out.write(hdl)
        print(hdl)

if __name__ == '__main__':
    main()
