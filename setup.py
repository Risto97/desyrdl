
# DesyRDL
# setup.py package script

from setuptools import find_packages, setup

setup(
    name="DesyRDL",
    version="0.1.2",

    description="DesyRDL: Tool for address space and registers generation",

    # package and requirements
    # packages=find_packages('desyrdl'),
    packages=["desyrdl"],

    include_package_data=True,

    # data_files=[('vhdl_tpl',
    #              [
    #                  './templates/top.vhd.in',
    #                  './templates/pkg_reg.vhd.in',
    #              ]),
    #             ('map_tpl',
    #              [
    #                 'templates/mapfile.mapp.in'
    #              ])
    #             ],

    install_requires=[
        "systemrdl-compiler >= 1.12",
    ],

    # Scripts
    entry_points={
        'console_scripts': ['desyrdl=desyrdl.desyrdl:main'],
    },

)
