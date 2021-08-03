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

            results = []
            for x in value:
                results.append(self.format(template, **x))

            return "".join(results)

        else:
            return super(RdlFormatter, self).format_field(value, spec)
