function load_results(query, features) {
   $("#results").empty()
   
   $("#results").append(get_def(query))
   
   for (i in features) {
      $("#results").append(get_candidates(query, features[i]))
   }
}

function get_candidates(query, feat) {
   dest = $("<div />", {"class": "featureset"})
   dest.append($("<h1 />").text(feat))
   
   $.getJSON("/cgi-bin/syn-diagnostic-lookup.pl", 
      {"query":query, "feature":feat},
      function(rec) {
         rec = rec.sort(function(a,b){return(b.score-a.score)})

         for (i in rec) {
            console.log(rec[i])
            div_res = get_def(rec[i].result, rec[i].score.toFixed(2))
            dest.append(div_res)
         }
      }
   )
   
   return(dest)
}


function get_def(query, score) {   
   div_def = $("<div />", {"class": "definition"})
   
   div_def_head = $("<div />", {"class":"head"})
   div_def_head.append($("<div />", {"class":"query"}).text(query))
   div_def_head.append($("<div />", {"class":"score"}).text(score))
   div_def.append(div_def_head)
   
   div_def_body = $("<div />", {"class":"body"})
   div_def_body.load("/cgi-bin/syn-diagnostic-def.pl", {"query":query})
   div_def.append(div_def_body)
   
   return(div_def)
}
