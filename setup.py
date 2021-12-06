#!/usr/bin/env python
"""DesyRDL tool.

setup.py installation package.
"""
from setuptools import setup

setup(
    name="DesyRDL",
    version="0.1.2",
    author="Michael Büchler <michael.buechler@desy.de>, Lukasz Butkowski <lukasz.butkowski@desy.de>",
    author_email="michael.buechler@desy.de",

    description="DesyRDL: Tool for address space and registers generation",

    # package and requirements
    packages=['desyrdl'],

    include_package_data=True,

    setup_requires=["wheel",
                    "setuptools>=42"],

    install_requires=[
        "systemrdl-compiler >= 1.12",
    ],

    # Scripts
    entry_points={
        'console_scripts': ['desyrdl=desyrdl.desyrdl:main'],
    },

)
