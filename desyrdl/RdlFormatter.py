# import os
import string
from math import ceil, log2

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker
from systemrdl.node import AddrmapNode, FieldNode  #, AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode


class RdlFormatter(string.Formatter):
    #    def __init__(self, top_node):
    #        super(RdlFormatter, self).__init__()
    #        top_node = top_node

    def context_add_interface(self, context, node):
        try:
            interface = node.get_property("interface")
        except LookupError:
            # handle standalone modules in a temporary way
            interface = "NONE"
            pass

        context["interface"] = interface

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
            #print(f"{node.inst_name} gets BAR {bar} from {ancestor.inst_name}")
        except LookupError:
            # handle standalone modules in a temporary way
            bar = 0
            pass
        finally:
            bar_start = ancestor.absolute_address


        context["bar"] = bar
        context["baraddr"] = node.absolute_address-bar_start

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
                    self.context_add_interface(newc, x[1])
                    self.context_add_bar(newc, x[1])

                    # format the template
                    results.append(self.format(template, context=newc))

                return "".join(results)

            else:
                return "-- VOID"  # this shouldn't happen
        else:
            return super(RdlFormatter, self).format_field(value, spec)
