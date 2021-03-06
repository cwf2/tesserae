function populate_author(lang, dest) {

	var select_full = $("#" + lang + "_texts").get(0)
	var select_auth = $("#sel_auth_" + dest).get(0)
	
	var authors = {}
	
	for (var i=0; i<select_full.length; i++) { 
	
		var opt_this = select_full.options[i]
		
		var seg_value = opt_this.value.split(".")
		var seg_name = opt_this.text.split(" - ")
						
		authors[seg_value[0]] = seg_name[0]		
	}
	
   $(select_auth).empty()
   
	for (var i in authors) {
	
		var opt_new = new Option(authors[i], i)
		select_auth.add(opt_new)
	}
	
   populate_work(lang,dest)
}

function populate_work(lang, dest) {

	var select_full = $("#" + lang + "_texts").get(0)
	var select_auth = $("#sel_auth_" + dest).get(0)
	var select_work = $("#sel_work_" + dest).get(0)
	
	var auth_master = select_auth.options[select_auth.selectedIndex].value
	var works = {}
	
	for (var i=0; i<select_full.length; i++) { 
	
		var opt_this = select_full.options[i]
		
		var seg_value = opt_this.value.split(".")
		var seg_name = opt_this.text.split(" - ")
		
		var auth_this = seg_value[0]
		var work_this = seg_value[1]
	
		if (auth_this == auth_master) {
			
			works[work_this] = seg_name[1]
		}
	}
			
	$(select_work).empty()
	
	for (var i in works) {
	
		var opt_new = new Option(works[i], i)
		select_work.add(opt_new)
	}
			
	populate_part(lang,dest)
}

function populate_part(lang, dest) {
	
	var select_full = $("#" + lang + "_texts").get(0)
	var select_auth = $("#sel_auth_" + dest).get(0)
	var select_work = $("#sel_work_" + dest).get(0)
	var select_part = $("#sel_part_" + dest).get(0)
	
	var auth_master = select_auth.options[select_auth.selectedIndex].value
	var work_master = select_work.options[select_work.selectedIndex].value
	var parts = {};
	
	for (var i=0; i<select_full.length; i++) { 
	
		var opt_this = select_full.options[i]
		
		var seg_value = opt_this.value.split(".");
		var seg_name = opt_this.text.split(" - ");
		
		var auth_this = seg_value[0];
		var work_this = seg_value[1];
						
		if (auth_this == auth_master && work_this == work_master) {
			
			if (seg_name.length > 2) {
				
				parts[seg_name[2]] = opt_this.value
			}
			else {
			
				parts["Full Text"] = opt_this.value
			}
		}
	}
	
	$(select_part).empty()
	
	for (var i in parts) {
	
		var opt_new = new Option(i, parts[i])
		select_part.add(opt_new)
	}		
}

function populate_feature(features, sel_position) {

	var list_feature = document.getElementsByName('feature')[0];

	for (var feat in features) {
		var opt = document.createElement('option');
		opt.value = feat;
		opt.text = features[feat];

		list_feature.add(opt);
		
		list_feature.selectedIndex=sel_position;
	}
}

function set_defaults(lang, selected) {
		
	for (dest in selected) {      	
   	var select_auth = $("#sel_auth_" + dest).get(0)
   	var select_work = $("#sel_work_" + dest).get(0)
   	var select_part = $("#sel_part_" + dest).get(0)
		
		var seg = selected[dest].split('.');
		var auth = seg[0];
		var work = seg[1];
		
		for (var i=0; i < select_auth.options.length; i++) {
		
			if (select_auth.options[i].value == auth) {
			
				select_auth.selectedIndex = i;
			}
		}
		
		populate_work(lang[dest],dest);

		for (var i=0; i < select_work.options.length; i++) {
		
			if (select_work.options[i].value == work) {
		
				select_work.selectedIndex = i;
			}
		}
		
		populate_part(lang[dest],dest);

		for (var i=0; i < select_part.options.length; i++) {
		
			if (select_part.options[i].value == selected[dest]) {
			
				select_part.selectedIndex = i;
			}
		}
	}	
}

function toggleAdvanced(isAdv) {

   var msg = ""

   if (isAdv) {
      msg = "show advanced"
      $(".advanced").hide()
   } else {
      msg = "hide advanced"
      $(".advanced").show()
   }

   $("#msg_advanced").html(msg)
}
