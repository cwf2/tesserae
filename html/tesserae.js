var presets = {
	la: {
		target_langs: "la",
		target_authors: "vergil",
		target_texts: "vergil.georgics",
		target_parts: "1",

		source_langs: "la",
		source_authors: "catullus",
		source_texts: "catullus.carmina",
		source_parts: "0",

		features: "stem",
		units: "line"
	},
	grc: {
		target_langs: "grc",
		target_authors: "apollonius",
		target_texts: "apollonius.argonautica",
		target_parts: "1",

		source_langs: "grc",
		source_authors: "homer",
		source_texts: "homer.iliad",
		source_parts: "0",

		features: "stem",
		units: "line"
	},
	knauer: {
		target_langs: "la",
		target_authors: "vergil",
		target_texts: "vergil.aeneid",
		target_parts: "1",

		source_langs: "grc",
		source_authors: "homer",
		source_texts: "homer.iliad",
		source_parts: "0",

		units: "phrase"
	},
	lucan: {
		target_langs: "la",
		target_authors: "lucan",
		target_texts: "lucan.bellum_civile",
		target_parts: "1",

		source_langs: "la",
		source_authors: "vergil",
		source_texts: "vergil.aeneid",
		source_parts: "0",

		features: "stem",
		units: "phrase"
	},
	val_flacc: {
		target_langs: "la",
		target_authors: "valerius_flaccus",
		target_texts: "valerius_flaccus.argonautica",
		target_parts: "9",

		source_langs: "la",
		source_authors: "vergil",
		source_texts: "vergil.aeneid",
		source_parts: "0",

		features: "stem",
		units: "line"
	}
}

function get_authors(prefix) {
	var preset = presets[$("#sel_preset").val()]
	var request = "/cgi-bin/metadata_authors.pl"
	var criteria = {
		lang: preset[prefix + "_langs"]
	}
	var dest = prefix + "_authors"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
		get_texts(prefix)
	}
	
	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_texts(prefix) {

	var preset = presets[$("#sel_preset").val()]
	var request = "/cgi-bin/metadata_texts.pl"
	var criteria = {
		Author: $("#sel_" + prefix + "_authors").val()
	}
	var dest = prefix + "_texts"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
		get_features()
		get_units()
		get_parts(prefix)
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_parts(prefix) {

	var preset = presets[$("#sel_preset").val()]
	var request = "/cgi-bin/metadata_parts.pl"
	var criteria = {
		textid: $("#sel_" + prefix + "_texts").val()
	}
	var dest = prefix + "_parts"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function get_features() {

	var preset = presets[$("#sel_preset").val()]
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

function get_units() {

	var preset = presets[$("#sel_preset").val()]
	var request = "/cgi-bin/metadata_units.pl"
	var criteria = {
		target: $("#sel_target_texts").val(),
		source: $("#sel_source_texts").val()
	}
	var dest = "units"
	var callback = function(jsonlist) {
		populate_dropdown($("#sel_"+dest), jsonlist, preset[dest])
	}

	$("#sel_"+dest).empty()
	$.getJSON(request, criteria, callback)
}

function populate_dropdown(dropdown, jsonlist, selected) {
	dropdown.empty()

	for (i in jsonlist) {
		var o = jQuery("<option />", {
			value: jsonlist[i].value,
			text: jsonlist[i].display
		})

		dropdown.append(o)

		if (selected != undefined) {
			if (jsonlist[i].value == selected) { 
				dropdown.val(jsonlist[i].value)
			}
		}
	}
}

function init_form() {
	$("#sel_preset").empty()

	for (i in presets) {
		var o = jQuery("<option />", {
			value: i,
			text: i
		})
		$("#sel_preset").append(o)
	}

	get_authors("source")
	get_authors("target")
}

function highlight_result(r) {
	for (var j = 0; j < r.marked_source.length; j ++) {
		$("#source .t" + r.marked_source[j]).css("color", "red")
	}
	for (var j = 0; j < r.marked_target.length; j ++) {
		$("#target .t" + r.marked_target[j]).css("color", "red")
	}
}

