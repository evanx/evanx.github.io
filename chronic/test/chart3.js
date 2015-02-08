var app = angular.module("anglesExample", ["angles"]);

app.controller("chartController", function($scope, $http) {

   $scope.metricList = function() {
      console.log("metricList");
      $scope.metrics = undefined;
      $scope.selected = undefined;
      $scope.loading = true;
      $http.post("/chronicapp/metricList", {
      }).then(function(response) {
         $scope.loading = false;
         $scope.charts = undefined;
         if (response.data && response.data.metrics) {
            console.log("metrics", response.data.metrics);
            $scope.metrics = response.data.metrics;
            $scope.chartMetrics();
         } else {
            console.warn("metrics", response);
         }
      });
   };

   $scope.metricList();

   $scope.chartMetrics = function() {
      var charts = [];
      for (var i = 0; i < $scope.metrics.length; i++) {
         var chart = {
            topicLabel: $scope.metrics[i].topicLabel,
            metricLabel: $scope.metrics[i].metricLabel,
            labels: $scope.metrics[i].labels,
            datasets: [
               {
                  fillColor: "rgba(151,187,205,0)",
                  strokeColor: "#e67e22",
                  pointColor: "rgba(151,187,205,0)",
                  pointStrokeColor: "#e67e22",
                  data: $scope.metrics[i].data
               }
            ]
         };
         charts.push(chart);
      }
      $scope.charts = charts;
   };

   $scope.options = {
      pointDotRadius : 2,
      pointDotStrokeWidth : 1,
      scaleShowLabels : true,
      scaleOverlay : false,
      scaleOverride : false,
      scaleSteps : 3,
      scaleStepWidth : 2,
      scaleStartValue : 0,      
      segmentShowStroke: false
   }
})
