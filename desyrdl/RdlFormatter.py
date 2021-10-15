# import os
import string

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker
from systemrdl.node import (AddrmapNode, FieldNode,  # , AddressableNode
                            MemNode, RegfileNode, RegNode, RootNode)


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
            #     check on
            #   * the integer to compare with
            #   * the template to format, if the check succeeds
            # "value" is the value to apply the check to
            (check,name,compareval,template) = args.split(":", maxsplit=3)
            def do_format():
                return self.format(template, context=value, **value)

            # compare with int, if string cannot be coveted to string compare strings
            try:
                if check == "eq" and value[name] == int(compareval):
                    return do_format()
                if check == "ne" and value[name] != int(compareval):
                    return do_format()
            except ValueError:
                if check == "eq" and value[name] == compareval:
                    return do_format()
                if check == "ne" and value[name] != compareval:
                    return do_format()
            try:
                if check == "gt" and value[name] > int(compareval):
                    return do_format()
                if check == "lt" and value[name] < int(compareval):
                    return do_format()
                if check == "ge" and value[name] >= int(compareval):
                    return do_format()
                if check == "le" and value[name] <= int(compareval):
                    return do_format()
            except ValueError:
                print(f'if with string can by used only with eq,ne; if:{check}:{name}:{compareval} ')

            # return an empty string if the check fails
            return ""

        else:
            return super(RdlFormatter, self).format_field(value, spec)
