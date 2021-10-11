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
                results.append(self.format(args, context=x, **x))

            return "".join(results)

        if func == "if":
            # "args" is further separated by ':':
            #   * the check to be performed
            #   * the name of the dict entry in 'value' to perform the
            #     ckeck on
            #   * the template to format, if the check succeeds
            # "value" is the value to apply the check to
            (check,sep,tmp) = args.partition(":")
            (name,sep,template) = tmp.partition(":")
            def do_format():
                return self.format(template, context=value, **value)

            if check == "gtzero" and value[name] > 0:
                return do_format()
            if check == "ltzero" and value[name] < 0:
                return do_format()
            if check == "eqzero" and value[name] == 0:
                return do_format()
            if check == "nezero" and value[name] != 0:
                return do_format()

            # return an empty string if the check fails
            return ""

        else:
            return super(RdlFormatter, self).format_field(value, spec)
