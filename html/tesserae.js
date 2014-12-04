var presets = {
	la: {
		target_langs: "la",
		target_authors: "vergil",
		target_texts: "vergil.georgics",
		target_parts: "vergil.georgics.part.1",

		source_langs: "la",
		source_authors: "catullus",
		source_texts: "catullus.carmina",
		source_parts: "catullus.carmina",

		features: "stem",
		units: "line"
	},
	grc: {
		target_langs: "grc",
		target_authors: "apollonius",
		target_texts: "apollonius.argonautica",
		target_parts: "apollonius.argonautica.part.1",

		source_langs: "grc",
		source_authors: "homer",
		source_texts: "homer.iliad",
		source_parts: "homer.iliad",

		features: "stem",
		units: "line"
	},
	knauer: {
		target_langs: "la",
		target_authors: "vergil",
		target_texts: "vergil.aeneid",
		target_parts: "vergil.aeneid.part.1",

		source_langs: "grc",
		source_authors: "homer",
		source_texts: "homer.iliad",
		source_parts: "homer.iliad",

		features: "trans1",
		units: "phrase"
	},
	lucan: {
		target_langs: "la",
		target_authors: "lucan",
		target_texts: "lucan.bellum_civile",
		target_parts: "lucan.bellum_civile.part.1",

		source_langs: "la",
		source_authors: "vergil",
		source_texts: "vergil.aeneid",
		source_parts: "vergil.aeneid.part.1",

		features: "stem",
		units: "phrase"
	}
}

function get_langs(prefix) {
	var request = "/cgi-bin/metadata_langs.pl"
	var criteria = {}
	var dest = $("#sel_" + prefix + "_langs")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
		get_authors(prefix)
	}

	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function get_authors(prefix) {
	var request = "/cgi-bin/metadata_authors.pl"
	var criteria = {
		lang: $("#sel_" + prefix + "_langs").val()
	}
	var dest = $("#sel_" + prefix + "_authors")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
		get_texts(prefix)
	}
	
	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function get_texts(prefix) {
	var request = "/cgi-bin/metadata_texts.pl"
	var criteria = {
		author: $("#sel_" + prefix + "_authors").val()
	}
	var dest = $("#sel_" + prefix + "_texts")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
		get_features()
		get_units()
		get_parts(prefix)
	}

	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function get_parts(prefix) {
	var request = "/cgi-bin/metadata_parts.pl"
	var criteria = {
		name: $("#sel_" + prefix + "_texts").val()
	}
	var dest = $("#sel_" + prefix + "_parts")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
	}

	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function get_features() {
	var request = "/cgi-bin/metadata_features.pl"
	var criteria = {
		target: $("#sel_target_texts").val(),
		source: $("#sel_source_texts").val()
	}
	var dest = $("#sel_features")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
	}

	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function get_units() {
	var request = "/cgi-bin/metadata_units.pl"
	var criteria = {
		target: $("#sel_target_texts").val(),
		source: $("#sel_source_texts").val()
	}
	var dest = $("#sel_units")
	var callback = function(jsonlist) {
		populate_dropdown(dest, jsonlist)
	}

	//dest.empty()
	$.getJSON(request, criteria, callback)
}

function populate_dropdown(dropdown, jsonlist) {
	dropdown.empty()

	for (i in jsonlist) {
		var o = jQuery("<option />", {
			value: jsonlist[i].name,
			text: jsonlist[i].display
		})

		dropdown.append(o)
	}
}


function set_defaults(preset, dest) {
/*
	$("#sel_source_" + dest).val(presets[preset]["source_langs"]).change()
	$("#sel_source_authors").val(presets[preset]["source_authors"]).change()
	$("#sel_source_texts").val(presets[preset]["source_texts"]).change()
	$("#sel_source_parts").val(presets[preset]["source_parts"]).change()

	$("#sel_target_langs").val(presets[preset]["target_langs"]).change()
	$("#sel_target_authors").val(presets[preset]["target_authors"]).change()
	$("#sel_target_texts").val(presets[preset]["target_texts"]).change()
	$("#sel_target_parts").val(presets[preset]["target_parts"]).change()

	$("#sel_features").val(presets[preset]["features"]).change()
	$("#sel_units").val(presets[preset]["units"]).change()
*/
}
