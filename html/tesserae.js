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

function get_langs(prefix, preset_label) {
	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_langs.pl"
	var criteria = {}
	var dest = prefix + "_langs"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
		get_authors(prefix, preset_label)
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_authors(prefix, preset_label) {

	if (preset_label == undefined) { 
		preset_label = $("#sel_" + prefix + "_langs").val() 
	}
	
	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_authors.pl"
	var criteria = {
		lang: $("#sel_" + prefix + "_langs").val()
	}
	var dest = prefix + "_authors"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
		get_texts(prefix, preset_label)
	}
	
	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_texts(prefix, preset_label) {

	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_texts.pl"
	var criteria = {
		author: $("#sel_" + prefix + "_authors").val()
	}
	var dest = prefix + "_texts"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
		get_features(preset_label)
		get_units(preset_label)
		get_parts(prefix, preset_label)
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_parts(prefix, preset_label) {

	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_parts.pl"
	var criteria = {
		name: $("#sel_" + prefix + "_texts").val()
	}
	var dest = prefix + "_parts"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_features(preset_label) {

	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_features.pl"
	var criteria = {
		target: $("#sel_target_texts").val(),
		source: $("#sel_source_texts").val()
	}
	var dest = "features"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_units(preset_label) {

	var preset = presets[preset_label]
	var request = "/cgi-bin/metadata_units.pl"
	var criteria = {
		target: $("#sel_target_texts").val(),
		source: $("#sel_source_texts").val()
	}
	var dest = "units"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist)
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function populate_dropdown(dropdown, jsonlist, selected) {
	dropdown.empty()

	for (i in jsonlist) {
		var o = jQuery("<option />", {
			value: jsonlist[i].name,
			text: jsonlist[i].display
		})

		dropdown.append(o)

		if (selected != undefined) {
			if (jsonlist[i].name == selected) { 
				dropdown.val(jsonlist[i].name)
			}
		}
	}
}


