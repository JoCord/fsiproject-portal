/*!
   fsi.js
   
   This program is free software; you can redistribute it and/or modify it under the
   terms of the GNU General Public License as published by the Free Software Foundation;
   either version 3 of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
   See the GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along with this program;
   if not, see <http://www.gnu.org/licenses/>.

*/
var endCount_s = 0;
var actCount_s = 0;

function CheckAll(x) {
    var allInputs = document.getElementsByName(x.name);
    for (var i = 0, max = allInputs.length; i < max; i++) {
        if (allInputs[i].type == 'checkbox') {
            var classList = allInputs[i].className.split(' ');
            // window.alert("Class :" + allInputs[i].name + '/' + allInputs[i].id + '/' + classList);
            if (classList.indexOf('filtered')) {
                if (x.checked === true) {
                    allInputs[i].checked = true;
                } else {
                    allInputs[i].checked = false;
                }
            }
        }
    }
}

function CheckTable(x, h) {
   //   window.alert('Check: ' + h);   
   var allInputs = document.getElementsByName(x.name);
   for (var i = 0, max = allInputs.length; i < max; i++) {
      if (allInputs[i].type == 'checkbox') {
         //      if (allInputs[i].id == h)
         if (allInputs[i].id.startsWith(h)) {
            if (x.checked === true) {
               allInputs[i].checked = true;
            } else {
               allInputs[i].checked = false;
            }
         }
      }
   }
}

function CreateDaemonStat() {
   $.getJSON("/fsidaemon", function (json) {
      $(".chkdaemon").attr("src","/images/" + json.Items[0].check + ".png");
      $(".ondaemon").attr("src","/images/" + json.Items[0].online + ".png");
   });
}
      


function CreateStatList() {
   $.getJSON("/fsistat", function (json) {
      var actCount = 0,
         endCont = 0,
         tkey;
      for (tkey in json.Items) {
         endCount = tkey;
         actCount++;
      }
      if ((endCount != endCount_s) || (actCount != actCount_s)) {

         $('a.fsiTask').unbind("click");

         $('#status-ticker ul').empty();
         endCount_s = endCount;
         actCount_s = actCount;
         var key;
         for (key in json.Items) {
            $('#status-ticker ul').append('<li><a class="fsiTask" href="#' + json.Items[key].url + '" data-dismiss="modal" data-toggle="modal" data-src="http://' +
               json.Items[key].vitemp + '/fsitail/log.html#logs/' + json.Items[key].logdatei + '" rel="tooltip" title="' +
               json.Items[key].long + '" >' + json.Items[key].short + '</a></li>');
         }
         if (json.Items[key].short == "Waiting ...") {
            $('#status-count').empty();
            $('#status-count').append('No Background Tasks ');
         }
         else {
            $('#status-count').empty();
            $('#status-count').append('Background Tasks: ' + actCount + ' ');
         }
         $('a.fsiTask').on('click', function (e) {
            var src = $(this).attr('data-src');
            // window.alert('Open fsi task for '+src);
            var height = $(this).attr('data-height') || 600;
            // var width = $(this).attr('data-width') || 870;
            // $("#myShowTask object").attr({'data': src,'height': height,'width': width});
            $("#myShowTask object").attr({
               'data': src,
               'height': height
            });
         });
         $('#myShowTask').on('hidden.bs.modal', function () {
            // window.alert('ShowLog Closed');
            $("#myShowTask object").attr({
               'data': '#'
            });
         });
      }
   });
}

function GetInfo(typ, who) {
   $.getJSON("/fsigetinfo/" + typ + "/" + who, function (json) {
      if (json.Status['status'] == "finish") {
         window.location.reload(true);
      }
   });
}

