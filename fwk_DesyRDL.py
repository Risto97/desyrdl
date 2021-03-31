import string
import sys
from pathlib import Path

from systemrdl import RDLCompileError, RDLCompiler, RDLListener, RDLWalker
from systemrdl.node import AddrmapNode, FieldNode  #, AddressableNode
from systemrdl.node import MemNode, RegfileNode, RegNode, RootNode

from DesyListener import VhdlListener, MapfileListener
from RdlFormatter import RdlFormatter


def main():
    # All input arguments are SystemRDL source files and must be provided in
    # the correct order.
    rdlfiles = sys.argv[1:]

    # Create an instance of the compiler
    rdlc = RDLCompiler()

    # Compile and elaborate to obtain the hierarchical model
    try:
        for rdlfile in rdlfiles:
            rdlc.compile_file(rdlfile)
        root = rdlc.elaborate()
    except RDLCompileError:
        # A compilation error occurred. Exit with error code
        sys.exit(1)
    if isinstance(root, RootNode):
        top_node = root.top
    else:
        #top_node = root
        raise Error("root is not a RootNode")

    # Template engine
    vf = RdlFormatter()

    out_dir = Path("out")
    out_dir.mkdir(exist_ok=True)

    # Generate from VHDL templates
    basedir = Path(__file__).parent.absolute()
    tpldir = basedir / "templates"
    for tpl in tpldir.glob('*.vhd.in'):
        listener = VhdlListener(vf, tpl, out_dir)
        tpl_walker = RDLWalker(unroll=True)
        tpl_walker.walk(top_node, listener)

    # Generate mapfile from template
    tpl = tpldir / "mapfile.mapp.in"
    listener = MapfileListener(vf, tpl, out_dir)
    tpl_walker = RDLWalker(unroll=True)
    tpl_walker.walk(top_node, listener)

if __name__ == '__main__':
    main()
