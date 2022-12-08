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
# @date 2021-04-07
# @author Michael Buechler <michael.buechler@desy.de>
# @author Lukasz Butkowski <lukasz.butkowski@desy.de>
# --------------------------------------------------------------------------- #
"""DesyRDL tool.

Use of Python SystemRDL compiler to generate VHDL and address map artifacts.
"""

import argparse
import sys
from pathlib import Path
from shutil import copy

from systemrdl import RDLCompileError, RDLCompiler, RDLWalker  # RDLListener
from systemrdl.node import (AddrmapNode, FieldNode, MemNode,  # AddressableNode
                            RegfileNode, RegNode, RootNode)

from desyrdl.DesyListener import AdocListener, MapfileListener, VhdlListener
from desyrdl.RdlFormatter import RdlFormatter


def main():
    """Run main process of DesyRDL tool.

    All input arguments are SystemRDL source files and must be provided in
    the correct order.

    ----------------------------------
    Parse arguments
    desyrdl  <input file/s>
    desyrdl -f vhdl -i <input file/s> -t <template folder> -o <output_dir> -h <help>
    """
    argParser = argparse.ArgumentParser('DesyRDL command line options')
    # argParser.add_argument('input_files',
    #                        metavar='file.rdl',
    #                        nargs='+',
    #                        help='input rdl file/files, in bottom to root order')
    argParser.add_argument('-i', '--input-files',
                           dest="input_files",
                           metavar='file1.rdl',
                           nargs='+',
                           help='input rdl file/files, in bottom to root order')
    argParser.add_argument('-f', '--format-out',
                           dest="out_format",
                           metavar='FORMAT',
                           required=True,
                           nargs='+',  # allow multiple values
                           choices=['vhdl', 'map', 'h', 'adoc'],
                           help='output format: vhdl, map, h')
    argParser.add_argument('-o', '--output-dir',
                           dest="out_dir",
                           metavar='DIR',
                           default='./',
                           help='output directory, default the current dir ./')
    argParser.add_argument('-t', '--templates-dir',
                           dest="tpl_dir",
                           metavar='DIR',
                           help='[optional] location of templates dir')

    args = argParser.parse_args()

    # ----------------------------------
    # setup variables
    # basedir = Path(__file__).parent.absolute()
    if args.tpl_dir is None:
        tpl_dir = Path(__file__).parent.resolve() / "./templates"
        print('INFO: Using default templates directory: ' + str(tpl_dir))
    else:
        tpl_dir = Path(args.tpl_dir).resolve()
        print('INFO: Using custom templates directory ' + str(tpl_dir))

    # location of libraries that are provided for SystemRDL and each output
    # format
    lib_dir = Path(__file__).parent.resolve() / "./libraries"
    print('INFO: Taking common libraries from ' + str(lib_dir))

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(exist_ok=True)

    rdlfiles = list()
    rdlfiles.extend(sorted(Path(lib_dir / "rdl").glob("*.rdl")))
    rdlfiles.extend(args.input_files)

    # ----------------------------------
    # Create an instance of the compiler
    rdlc = RDLCompiler()

    # Compile and elaborate to obtain the hierarchical model
    try:
        for rdlfile in rdlfiles:
            rdlc.compile_file(rdlfile)
        root = rdlc.elaborate()
    except Exception as e:  # RDLCompileError
        # A compilation error occurred. Exit with error code
        print('\nERROR: Failed to compile RDL files: ' + str(e))
        sys.exit(1)

    # ----------------------------------
    # Check root node
    if isinstance(root, RootNode):
        top_node = root.top
    else:
        print('#\nERROR: root is not a RootNode')
        sys.exit(2)

    # ----------------------------------
    # DesyRDL Template engine
    vf = RdlFormatter()

    # ----------------------------------
    # GENERATE OUT
    # ----------------------------------
    # select format-action dependently on for type, iterate over the list
    for out_format in args.out_format:
        # target file where to list all output files, either copied from
        # libraries or generated
        fname_out_list = Path(out_dir / f'gen_files_{out_format}.txt')

        # try getting an ordered list of templates to use
        tpl_files = []
        lib_files = []
        fname_in_list = Path(tpl_dir / out_format / 'include.txt')
        try:
            with fname_in_list.open('r') as f_in:
                # - Ignore lines starting with a '#'
                # - Separator is a space (' ')
                # - Two elements per line: "template_file outfile_template_string"
                for line in f_in:
                    if line[0] == '#':
                        continue
                    (tpl_in, tpl_tplstr) = line.strip('\n').split(' ')
                    # add a tuple (template, template string)
                    tpl_files.append((Path(tpl_dir / out_format / tpl_in), tpl_tplstr))
        except FileNotFoundError:
            # attention: this will include hidden files, e.g. .my_tpl.vhd.swp
            print('Using glob to find templates')
            tpl_in = [fname for fname in Path(tpl_dir / out_format).glob('*')]
            for fname in tpl_in:
                tpl_name = ''.join([fname.name.partition('.')[0], '_', '{node.type_name}'])
                tpl_suffixes = ''.join(fname.suffixes[:-1])  # just leave out the ".in"
                tpl_tplstr = ''.join([tpl_name, tpl_suffixes])
                # add a tuple (template, template string)
                tpl_files.append((Path(tpl_dir / out_format / fname), tpl_tplstr))

        # get a list of common libraries per output type
        fname_in_list = Path(lib_dir / out_format / 'include.txt')
        try:
            with fname_in_list.open('r') as f_in:
                for line in f_in:
                    if line[0] == '#':
                        continue
                    lib_files.append(Path(lib_dir / out_format / line.strip('\n')))
        except FileNotFoundError:
            print('Using glob to find libraries')
            lib_files = [fname for fname in Path(lib_dir / out_format).glob('*')]

        if out_format == 'vhdl':
            # Generate from VHDL templates
            print('======================')
            print('Generating VHDL files')
            print('======================')
            listener = VhdlListener(vf, tpl_files, out_dir, separator='_')
            tpl_walker = RDLWalker(unroll=True)
            tpl_walker.walk(top_node, listener)
        elif out_format == 'map':
            # Generate mapfile from template
            print('======================')
            print('Generating map files')
            print('======================')
            listener = MapfileListener(vf, tpl_files, out_dir)
            tpl_walker = RDLWalker(unroll=True)
            tpl_walker.walk(top_node, listener)
        elif out_format == 'h':
            # Generate mapfile from template
            print('======================')
            print('Generating header files')
            print('======================')
            listener = MapfileListener(vf, tpl_files, out_dir, separator='_')
            tpl_walker = RDLWalker(unroll=True)
            tpl_walker.walk(top_node, listener)
        elif out_format == 'adoc':
            # Generate register descriptions from template
            print('======================')
            print('Generating AsciiDoc file')
            print('======================')
            listener = AdocListener(vf, tpl_files, out_dir)
            tpl_walker = RDLWalker(unroll=True)
            tpl_walker.walk(top_node, listener)

        print(f'List of output files in {fname_out_list}')
        with fname_out_list.open('w') as f_out:
            # copy all common files of the selected format into the out folder
            for lib in lib_files:
                copy(lib, out_dir)
                f_out.write(f'{Path(out_dir / lib.name)!s}\n')
            for fname in listener.get_generated_files():
                f_out.write(f'{fname!s}\n')

    # argparse takes care about it
    # else:
    #     print('ERROR: Not supported output format: ' + args.out_format)


if __name__ == '__main__':
    main()
