import copy
import os
import re
import sys

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker

# template file paths
tpl_top = "templates/top.vhd.in"
tpl_adapter = "templates/adapter_axi4.vhd.in"

# RDL file name
rdlfile = "marsupials.rdl"

rdlc = RDLCompiler()
rdlc.compile_file(rdlfile)

try:
    root=rdlc.elaborate()
except RDLCompileError:
    print("oops")

top_node = root.get_child_by_name("marsupials")

print("children")
for child in top_node.children(unroll=True):
    #print(child.list_properties(list_all=True))
    print(child.get_property("name"))
    print(child.type_name)

def duplicate_regnames(s):
    # apply to: top.vhd
    # instantiate registers: 1. looop over regnames
    print("regs")
    regidx = 0
    base = 0
    regtypes = {}

    result = ""

    re_begin = re.compile("BEGIN duplicate for each regname", re.M)
    re_end = re.compile("END duplicate for each regname", re.M)

    match = re_begin.search(s)
    if match:
        result += s[:match.start()]

        m_end = re_end.search(s, match.start())
        if m_end:
            s_reg = s[match.start():m_end.end()]
            print("duplicate secition found at {} to {}".format(match.start(),m_end.end()))
        else:
            print("Error: duplicate section for regname is empty")
            s_reg = ""

        for reg in top_node.registers():
            # top_node.registers() are what I called "regname"s, so one per array
            print(reg.get_property("name"))
            print(reg.type_name)

            # add type to a list of tuples regtype:reg
            if not reg.type_name in regtypes:
                regtypes[reg.type_name] = reg

            # find section to duplicate and store in a buffer
            #  sed -n '/START duplication regname/,/END duplication/p'
            s_thisreg = copy.deepcopy(s_reg)
            s_thisreg = re.sub(
                    r'<regname>',
                    reg.get_property("name"),
                    s_thisreg)
            s_thisreg = re.sub(
                    r'<regtype>',
                    reg.type_name,
                    s_thisreg)
            s_thisreg = re.sub(
                    r'<i>',
                    '{}'.format(regidx),
                    s_thisreg)

            result += s_thisreg

            #for field in reg.fields():

            print("regname {}, regtype {}".format(reg.get_property("name"), reg.type_name))
            # <regname> -> reg.get_property("name")
            # <regtype> -> reg.type_name
            regidx += 1

            if reg.is_array:
                # must go to C_REGISTER_INFO. for position inside VHDL in/out records.
                base_inc = 1
                for i in range(len(reg.array_dimensions)):
                    base_inc *= reg.array_dimensions[i]
                base += base_inc

                if len(reg.array_dimensions) == 2:
                    # assuming RDL "regtype regname[N][M]"
                    N = reg.array_dimensions[0]
                    M = reg.array_dimensions[1]
                elif len(reg.array_dimensions) == 1:
                    N = 1
                    M = reg.array_dimensions[0]
                else:
                    print("FIXME: more than 2 array dimensions are neither supported nor handled properly")

            else:
                base += 1
                N = 1
                M = 1

            print(regtypes)

        print(s[m_end.start():m_end.end()])
        result += s[m_end.end():]

    else:
        result = s
        print("not a match")

    return result

### UNUSED
def tpl_duplicate_lines(s):
    # find line with string "-- BEGIN duplicate"
    #   if found
    #       start loop to know each regtype
    #       call self with the rest
    #   else
    #       start loop
    #       perform duplication until next "-- END duplicate"
    #       implies individual substitution for each duplicate
    # else return result
    match = re.search("BEGIN duplicate for each (?P<loopvar>[a-zA-Z_0-9]+)", s)
    if match:
        tpl_duplicate_lines(s[match.start():], loopvar=match.group("loopvar"))


with open(tpl_top, 'r') as f_in:
    s_in = f_in.read()

s_out = duplicate_regnames(s_in)

with open('top.vhd', 'w') as f_out:
    f_out.write(s_out)
