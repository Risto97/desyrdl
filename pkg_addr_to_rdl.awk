#!/usr/bin/awk -f

# see gawk user guide Edition 5.1, 9.1.3 String-Manipulation Functions
function basename(path) {
	# split by "/", store what's between separators in array a
	n = split(path, a, "/")
	return a[n]
}

function strip_spaces(s) {
	# no backreferences in awk (that's the simple answer)
	#sub(/\s*([a-zA-Z0-9_]+) */, "\1", s)
	gsub(/\s*/, "", s)
	return s
}

function make_sv_define(s) {
	# first split by math operators
	n_fields = split(s, fields, "[-+*/]")
	for (i = 1; i <= n_fields; i++) {
		# alphabetical characters are a pretty good indication of a
		# constant
		if (fields[i] ~ /[a-zA-Z]/) {
			gsub(fields[i], "`&", fields[i])
		}
	}
	return s
}

function II_get_parameters(s) {
	# first split by math operators
	n_fields = split(s, fields, "[-+*/]")
	for (i = 1; i <= n_fields; i++) {
		# alphabetical characters are a pretty good indication of a
		# constant
		if (fields[i] ~ /[a-zA-Z]/) {
			if (!(fields[i] in parameters)) {
				n_parameters++
				parameters[fields[i]] = fields[i]
			}
		}
	}

}

function II_get_type(type, name) {
	if (type == "VII_AREA") {
		# guess the type of item in this line by the item name
		n = split(name, a, "_")
		# AREA_ is probably a block RAM
		if (a[1] == "AREA") {
			return "mem"
		}
		# MISC_ is probably a downstream addrmap
		if (a[1] == "MISC") {
			return "ext"
		}
		# LLRF_ seems to be addrmaps, too
		if (a[1] == "LLRF") {
			return "ext"
		}
		# actually everything else is probably an addrmap, too
		return "ext"
	}

	if (type == "VII_WORD") {
		return "reg"
	}
}

function II_get_sw_access(W, R) {
	# observed in VII_AREA items but also some regular VII_WORD registers
	# that are probably wrong
	if (W == "VII_WACCESS" && R == "VII_REXTERNAL") {
		return "rw"
	}
	# observed in values reported by firmware,
	# also constants (e.g. revision)
	if (W == "VII_WNOACCESS" && R == "VII_REXTERNAL") {
		return "r"
	}
	# observed in regular registers set by software, never on VII_AREA
	if (W == "VII_WACCESS" && R == "VII_RINTERNAL") {
		return "rw"
	}
	# doesn't seem to occur
	if (W == "VII_WNOACCESS" && R == "VII_RINTERNAL") {
		return "invalid"
	}
	return "invalid, no match"
}

function II_get_hw_access(W, R) {
	# observed in VII_AREA items but also some regular VII_WORD registers
	# that are probably wrong
	if (W == "VII_WACCESS" && R == "VII_REXTERNAL") {
		return "rw"
	}
	# observed in values reported by firmware,
	# also constants (e.g. revision),
	# also AREA_DAQ_TIMES_x (hw only writes)
	if (W == "VII_WNOACCESS" && R == "VII_REXTERNAL") {
		return "w" # or "rw"?
	}
	# observed in regular registers set by software, never on VII_AREA
	if (W == "VII_WACCESS" && R == "VII_RINTERNAL") {
		return "r"
	}
	# doesn't seem to occur
	if (W == "VII_WNOACCESS" && R == "VII_RINTERNAL") {
		return "invalid"
	}
	return "invalid, no match"
}

BEGIN {
	FS = ","
}

{
	# count up for each of these lists and drop anything after the first
	# list for now
	if ($0 ~ "TVIIItemDeclList") {
		n_lists++
		#printf "TVIIItemDeclList %d starts here: ", n_lists
		#print $0
	}

	# The last line of the list is missing the last comma, thus NF=8
	if ((NF == 8 || NF == 9) && n_lists == 1) {
		n_items++

		type[n_items] = strip_spaces($1)
		reg_name[n_items] = strip_spaces($2)
		width[n_items] = make_sv_define(strip_spaces($3))
		M[n_items] = make_sv_define(strip_spaces($4))
		write[n_items] = strip_spaces($5)
		read[n_items] = strip_spaces($6)
		addr[n_items] = strip_spaces($7)
		format[n_items] = strip_spaces($8)
		#fracbits[n_items] = strip_spaces($9)

		II_get_parameters(strip_spaces($3))
		II_get_parameters(strip_spaces($4))
		II_get_parameters(strip_spaces($7))
	}
}

END {
	modname = basename(ARGV[1])
	sub(/.vhd/, "", modname)
	print "// FIXME put a proper name for the addrmap"
	printf "addrmap %s ", modname
	if (n_parameters > 0) {
		printf "#("
		i = 0
		for (p in parameters) {
			i++
			printf "longint unsigned %s", parameters[p]
			if (i < n_parameters) printf ", "
		}
		printf ") "
	}
	print "{"

	for (i = 1; i <= n_items; i++) {
		if (format[i] == "VII_SIGNED")
			signed = 1
		else # VII_UNSIGNED
			signed = 0

		detected = II_get_type(type[i], reg_name[i])
		if (detected == "reg") {
			sw = II_get_sw_access(write[i], read[i])
			hw = II_get_hw_access(write[i], read[i])
			print  "  reg {"
			print  "    field {"
			print  "      desc  = \"TODO\" ;"
			printf "      sw    = %s ;\n", sw
			printf "      hw    = %s ;\n", hw
			printf "    } data[%s] ;\n", width[i]
			printf "  } %s[%s] ;\n\n", reg_name[i], M[i]
		}
		if (detected == "mem") {
			print  "  external mem {"
			printf "    mementries = %s ;\n", M[i]
			printf "    memwidth   = %s ;\n", width[i]
			print  "    sw         = rw ;"
			printf "  } %s ;\n\n", reg_name[i]
		}
		if (detected == "ext") {
			printf "  FIXME %s ;\n\n", reg_name[i]
		}
	}
	print  "} ;"
}
