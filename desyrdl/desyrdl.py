#!/usr/bin/env python
# --------------------------------------------------------------------------- #
#           ____  _____________  __                                           #
#          / __ \/ ____/ ___/\ \/ /                 _   _   _                 #
#         / / / / __/  \__ \  \  /                 / \ / \ / \                #
#        / /_/ / /___ ___/ /  / /               = ( M | S | K )=              #
#       /_____/_____//____/  /_/                   \_/ \_/ \_/                #
#                                                                             #
# --------------------------------------------------------------------------- #
# @copyright Copyright 2021-2022 DESY
# SPDX-License-Identifier: Apache-2.0
# --------------------------------------------------------------------------- #
# @date 2021-04-07/2023-02-15
# @author Michael Buechler <michael.buechler@desy.de>
# @author Lukasz Butkowski <lukasz.butkowski@desy.de>
# --------------------------------------------------------------------------- #
"""DesyRDL tool.

Use of Python SystemRDL compiler to generate VHDL and address map artifacts.
"""

import argparse
import sys
from pathlib import Path

from systemrdl import RDLCompiler, RDLWalker
from systemrdl.messages import MessagePrinter, Severity
from systemrdl.node import RootNode

from desyrdl.DesyListener import DesyRdlProcessor


def main():
    """Run main process of DesyRDL tool.

    All input arguments are SystemRDL source files and must be provided in
    the correct order.

    # -------------------------------------------------------------------------
    Parse arguments
    desyrdl  <input file/s>
    desyrdl -f vhdl -i <input file/s> -t <template folder> -o <output_dir> -h <help>
    """
    arg_parser = argparse.ArgumentParser('DesyRDL command line options')
    arg_parser.add_argument(
        '-i',
        '--input-files',
        dest="input_files",
        metavar='file1.rdl',
        required=True,
        nargs='+',
        help='input rdl file/files, in bottom to root order',
    )
    arg_parser.add_argument(
        '-f',
        '--format-out',
        dest="out_format",
        metavar='FORMAT',
        required=True,
        nargs='+',  # allow multiple values
        choices=['vhdl', 'map', 'h', 'adoc', 'cocotb', 'tcl'],
        help='output format: vhdl, map, h',
    )
    arg_parser.add_argument(
        '-o',
        '--output-dir',
        dest="out_dir",
        metavar='DIR',
        default='./',
        help='output directory, default the current dir ./',
    )
    arg_parser.add_argument(
        '-l',
        '--user-lib-dirs',
        dest="user_lib_dirs",
        metavar='libdir',
        nargs='*',
        default=(),
        help='[optional] directory for user rdl libraries',
    )

    arg_parser.add_argument(
        '-t', '--templates-dir', dest="tpl_dir", metavar='DIR', help='[optional] location of templates dir'
    )

    args = arg_parser.parse_args()

    # compiler print log
    msg_severity = Severity(5)
    msg_printer = MessagePrinter()
    # msg = MessageHandler(msg_printer)
    # -------------------------------------------------------------------------
    # setup variables
    # basedir = Path(__file__).parent.absolute()
    msg_printer.print_message(msg_severity.INFO, "Generating output for formats: " + str(args.out_format), src_ref=None)

    if args.tpl_dir is None:
        tpl_dir = Path(__file__).parent.resolve() / "./templates"
        msg_printer.print_message(msg_severity.INFO, "Using default templates directory: " + str(tpl_dir), src_ref=None)
    else:
        tpl_dir = Path(args.tpl_dir).resolve()
        msg_printer.print_message(msg_severity.INFO, "Using custom templates directory: " + str(tpl_dir), src_ref=None)

    # location of libraries that are provided for SystemRDL and each output
    # format
    lib_dir = Path(__file__).parent.resolve() / "./libraries"
    msg_printer.print_message(msg_severity.INFO, "Taking common libraries from " + str(lib_dir), src_ref=None)

    lib_input_files = list(Path(lib_dir / "rdl").glob("*.rdl"))
    for user_lib_dir in args.user_lib_dirs:
        lib_input_files.extend(Path(user_lib_dir).glob("*.rdl"))
        print('INFO: Taking user libraries from ' + user_lib_dir)

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(exist_ok=True)

    rdlfiles = []
    rdlfiles.extend(sorted(lib_input_files, key=lambda f: f.parts[-1]))  # Sorted ignoring dir
    rdlfiles.extend(args.input_files)

    # -------------------------------------------------------------------------
    # Create an instance of the compiler
    rdlc = RDLCompiler()

    # Compile and elaborate to obtain the hierarchical model
    try:
        for rdlfile in rdlfiles:
            rdlc.compile_file(rdlfile)
        root = rdlc.elaborate()
    except Exception as e:  # RDLCompileError
        # A compilation error occurred. Exit with error code
        msg_printer.print_message(msg_severity.ERROR, str(e), src_ref=None)
        sys.exit(1)

    msg_printer.print_message(msg_severity.INFO, "SystemRdl compiler done.", src_ref=None)

    # -------------------------------------------------------------------------
    # Check root node
    if isinstance(root, RootNode):
        top_node = root.top
    else:
        print('#\nERROR: root is not a RootNode')
        sys.exit(2)

    # -------------------------------------------------------------------------
    walker = RDLWalker(unroll=False)
    listener = DesyRdlProcessor(tpl_dir, lib_dir, out_dir, args.out_format)
    walker.walk(top_node, listener)

    generated_files = listener.get_generated_files()
    for out_format in args.out_format:
        # target file where to list all output files, either copied from
        # libraries or generated
        fname_out_list = Path(out_dir / f'gen_files_{out_format}.txt')
        with fname_out_list.open('w') as f_out:
            # copy all common files of the selected format into the out folder
            for fname in generated_files[out_format]:
                f_out.write(f"{fname!s}\n")

    msg_printer.print_message(msg_severity.INFO, "Generation of the output files done.", src_ref=None)


if __name__ == '__main__':
    main()
