"""Cheby context class creator and yml exporter."""

import yaml


class ChebyContext:
    """Cheby context class creator and yml exporter."""

    def export(self, file_path, context):
        """Export context to cheby file."""
        cheby_file = open(file_path, "w")
        yaml.dump(self.gen_addrmap_context(context),
                  cheby_file,
                  default_flow_style=False, sort_keys=False)
        cheby_file.close()

    def gen_addrmap_context(self, context):
        """Generate context for memory map with its childrens for cheby format."""
        cheby = {}
        cheby['name'] = context['inst_name']
        cheby['description'] = context['node'].get_property('name')
        if context['desc']:
            cheby['comment'] = context['desc']
        if context['interface'].lower() == "axi4l":
            cheby['bus'] = "axi4-lite-32"
        # cheby['x-map-info'] = {'memmap-version': "1.1.0"}
        if context['insts']:
            # memory-map childrens - items
            self.gen_item_context(cheby, context)
        memory_map = {}
        memory_map['memory-map'] = cheby
        return memory_map

    def gen_item_context(self, cheby, context):
        """Generate context for each cheby item in mem map: reg, block, mem."""
        cheby['children'] = []
        for inst in context['insts']:
            inst_dict = {}
            inst_dict['name'] = inst['inst_name']
            inst_dict['description'] = inst['node'].get_property('name')
            if inst['desc']:
                inst_dict['comment'] = inst['desc']

            if inst['dim'] == 1:
                inst_dict['address'] = inst['address_offset']

            item = {}
            if inst['node_type'] == "ADDRMAP":
                inst_dict['filename'] = f"{inst['inst_name']}.cheby"
                # print(f"---- {context['node'].inst.addr_align}")
                inst_dict['align'] = False
                # print(f"---- {inst['inst_name']}: {context['node'].get_property('addressing')}")
                inst_dict['include'] = True
                item = {"submap": inst_dict}

            if inst['node_type'] == "MEM":
                inst_dict['size'] = inst['total_size']
                inst_dict['memsize'] = inst['addresses']
                self.gen_item_context(inst_dict, inst)
                # if no virtual regs add one reg, cheby spec: mem have to have 1 reg
                if not inst['insts']:
                    inst_dict['children'] = [{"reg":
                                              {"name": "value",
                                               "access": inst['rw'].lower(),
                                               "width": 32}
                                              }]
                item = {"memory": inst_dict}

            if inst['node_type'] == "REG":
                inst_dict['width'] = inst['node'].get_property('accesswidth')
                inst_dict['access'] = inst['rw'].lower()
                if inst['fields']:
                    self.gen_field_context(inst_dict, inst['fields'])
                item = {"reg": inst_dict}

            if inst['node_type'] == "REGFILE":
                inst_dict['size'] = inst['total_size'] if inst['dim'] == 1 else inst['array_stride']
                inst_dict['align'] = False
                self.gen_item_context(inst_dict, inst)
                item = {"block": inst_dict}

            # 2D and 3D arrays - use repeat
            if inst['dim'] > 1:
                repeat = {}
                repeat['name'] = inst['inst_name']
                repeat['count'] = inst['dim_m']
                repeat['align'] = False
                if inst['dim'] == 2:
                    repeat['address'] = inst['address_offset']
                repeat['children'] = [item]
                item = {'repeat': repeat}
            if inst['dim'] > 2:
                repeat = {}
                repeat['name'] = inst['inst_name']
                repeat['count'] = inst['dim_n']
                repeat['align'] = False
                if inst['dim'] == 3:
                    repeat['address'] = inst['address_offset']
                repeat['children'] = [item]
                item = {'repeat': repeat}
            cheby['children'].append(item)

    def gen_field_context(self, cheby, fields):
        """Generate register field context for cheby."""
        cheby['children'] = []
        fieldsctx_list = []
        for field in fields:
            fieldctx = {}
            fieldctx['name'] = field.inst_name
            if field.name:
                fieldctx['description'] = field.name
            if field.desc:
                fieldctx['comment'] = field.desc
            if field.low == field.high:
                fieldctx['range'] = field.low
            else:
                fieldctx['range'] = f"{field.high}-{field.low}"
            if field.reset:
                fieldctx['preset'] = field.reset
            fieldsctx_list.append({"field": fieldctx})

        cheby['children'] = fieldsctx_list


