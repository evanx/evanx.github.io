var app = angular.module("anglesExample", ["angles"]);

function range(start, count) {
    if (arguments.length === 1) {
        count = start;
        start = 0;
    }
    var array = [];
    for (var i = 0; i < count; i++) {
        array.push(start + i);
    }
    return array;
}

function range5(start, count) {
   if (arguments.length === 1) {
      count = start;
      start = 0;
   }
   var array = [];
   for (var i = 0; i < count; i++) {
      if ((start + i) % 5 == 0) {
         array.push(start + i);
      } else {
         array.push("");
      }
   }
   return array;
}

function random(count) {
    var array = [];
    for (var i = 0; i < count; i++) {
        array.push(2 + Math.random());
    }
    return array;
}

app.controller("angCtrl", function($scope, $http) {


   $scope.chart = [{
         labels: range5(23, 21),
         datasets: [
            {
               fillColor: "rgba(151,187,205,0.5)",
               strokeColor: "rgba(151,187,205,1)",
               pointColor: "rgba(151,187,205,1)",
               pointStrokeColor: "#fff",
               data: random(21)
            }
         ]
      }]

   $scope.options = {
      pointDotRadius : 2,
      pointDotStrokeWidth : 1,
      scaleShowLabels : true,
      scaleOverlay : false,
	
      //Boolean - If we want to override with a hard coded scale
      scaleOverride : true,
	
      //Number - The number of steps in a hard coded scale
      scaleSteps : 3,
      
      //Number - The value jump in the hard coded scale
      scaleStepWidth : 2,
	
      //Number - The scale starting value
      scaleStartValue : 0,
      
      segmentShowStroke: false,      
   }
})
