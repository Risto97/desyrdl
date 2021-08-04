

import argparse
import sys
from pathlib import Path
from shutil import copy

from systemrdl import RDLCompileError, RDLCompiler, RDLWalker  # RDLListener
from systemrdl.node import (AddrmapNode, FieldNode, MemNode,  # AddressableNode
                            RegfileNode, RegNode, RootNode)

from desyrdl.DesyListener import MapfileListener, VhdlListener
from desyrdl.RdlFormatter import RdlFormatter


def main():
    # All input arguments are SystemRDL source files and must be provided in
    # the correct order.

    # ----------------------------------
    # Parse arguments
    # desyrdl  <input file/s>
    # desyrdl -f vhdl -i <input file/s> -t <template folder> -o <output_dir> -h <help>

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
    rdlfiles.extend(Path(lib_dir / "rdl").glob("*.rdl"))
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
        # copy all common files of the selected format into the out folder
        for lib in Path(lib_dir / out_format).glob('*'):
            copy(lib, out_dir)

        # attention: this will include hidden files, e.g. .my_tpl.vhd.swp
        tpl_files = Path(tpl_dir / out_format).glob('*')

        if out_format == 'vhdl':
            # Generate from VHDL templates
            print('======================')
            print('Generating VHDL files')
            print('======================')
            for tpl in tpl_files:
                listener = VhdlListener(vf, tpl, out_dir)
                tpl_walker = RDLWalker(unroll=True)
                tpl_walker.walk(top_node, listener)
        elif out_format == 'map':
            # Generate mapfile from template
            print('======================')
            print('Generating map files')
            print('======================')
            for tpl in tpl_files:
                listener = MapfileListener(vf, tpl, out_dir)
                tpl_walker = RDLWalker(unroll=True)
                tpl_walker.walk(top_node, listener)
        elif out_format == 'adoc':
            # Generate register descriptions from template
            print('======================')
            print('Generating AsciiDoc file')
            print('======================')
            for tpl in tpl_files:
                listener = MapfileListener(vf, tpl, out_dir)
                tpl_walker = RDLWalker(unroll=True)
                tpl_walker.walk(top_node, listener)

    # argparse takes care about it
    # else:
    #     print('ERROR: Not supported output format: ' + args.out_format)


if __name__ == '__main__':
    main()
