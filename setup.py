
# DesyRDL
# setup.py package script

from setuptools import find_packages, setup

setup(
    name="DesyRDL",
    version="0.1.2",
    author="Michael Büchler",
    author_email="michael.buechler@desy.de",

    description="DesyRDL: Tool for address space and registers generation",

    # package and requirements
    packages=['desyrdl'],

    include_package_data=True,

    install_requires=[
        "systemrdl-compiler >= 1.12",
    ],

    # Scripts
    entry_points={
        'console_scripts': ['desyrdl=desyrdl.desyrdl:main'],
    },

)
