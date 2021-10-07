# import os
import string

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker
from systemrdl.node import AddrmapNode, FieldNode  #, AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode


class RdlFormatter(string.Formatter):
    #    def __init__(self, top_node):
    #        super(RdlFormatter, self).__init__()
    #        top_node = top_node

    def format_field(self, value, spec):

        # parse the custom template engine spec
        (func,sep,args) = spec.partition(":")

        if func == "upper":
            return value.upper()

        if func == "lower":
            return value.lower()

        if func == "removeprefix":
            # "args" is the prefix
            if value.startswith(args):
                return value[len(args):]
            else:
                return value

        if func == "repeat":
            # "args" is the template string
            results = []
            for x in value:
                results.append(self.format(args, **x))

            return "".join(results)

        else:
            return super(RdlFormatter, self).format_field(value, spec)
