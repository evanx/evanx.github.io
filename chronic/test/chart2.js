var app = angular.module("anglesExample", ["angles"]);

app.controller("angCtrl", function($scope, $http) {

   $scope.metricList = function() {
      console.log("metricList");
      $scope.metrics = undefined;
      $scope.selected = undefined;
      $scope.loading = true;
      $http.post("/chronicapp/metricList", {
      }).then(function(response) {
         $scope.loading = false;
         if (response.data && response.data.metrics) {
            console.log("metrics", response.data.metrics[0].data);
            $scope.metrics = response.data.metrics;
         } else {
            console.warn("metrics", response);
         }
      });
   };

   $scope.metricList();

   if ($scope.metrics && $scope.metrics[0]) {
      $scope.chart = [{
            labels: [""],
            datasets: [
               {
                  fillColor: "rgba(151,187,205,0)",
                  strokeColor: "#e67e22",
                  pointColor: "rgba(151,187,205,0)",
                  pointStrokeColor: "#e67e22",
                  data: $scope.metrics[0].data
               }
            ]
         }]
   } else {
      $scope.chart = [
         {
            labels: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
            datasets: [
               {
                  fillColor: "rgba(151,187,205,0)",
                  strokeColor: "#e67e22",
                  pointColor: "rgba(151,187,205,0)",
                  pointStrokeColor: "#e67e22",
                  data: [4, 3, 5, 4, 6]
               },
               {
                  fillColor: "rgba(151,187,205,0)",
                  strokeColor: "#f1c40f",
                  pointColor: "rgba(151,187,205,0)",
                  pointStrokeColor: "#f1c40f",
                  data: [8, 3, 2, 5, 4]
               }
            ],
         }, {
            labels: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
            datasets: [
               {
                  fillColor: "#f1c40f",
                  strokeColor: "#f1c40f",
                  pointColor: "rgba(151,187,205,1)",
                  pointStrokeColor: "#fff",
                  data: [7, 3, 4, 6, 7]
               },
               {
                  fillColor: "#FF0000",
                  strokeColor: "#e67e22",
                  pointColor: "rgba(151,187,205,1)",
                  pointStrokeColor: "#fff",
                  data: [0, 3, 4, 6, 1]
               }
            ],
         }, {
            labels: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
            datasets: [
               {
                  fillColor: "#f1c40f",
                  strokeColor: "#f1c40f",
                  pointColor: "rgba(151,187,205,1)",
                  pointStrokeColor: "#fff",
                  data: [7, 3, 4, 6, 7]
               },
               {
                  fillColor: "#FF0000",
                  strokeColor: "#e67e22",
                  pointColor: "rgba(151,187,205,1)",
                  pointStrokeColor: "#fff",
                  data: [0, 3, 4, 6, 1]
               }
            ],
         }, [
            {
               value: 30,
               color: "#D97041"
            },
            {
               value: 90,
               color: "#C7604C"
            },
            {
               value: 24,
               color: "#21323D"
            },
            {
               value: 58,
               color: "#9D9B7F"
            },
            {
               value: 82,
               color: "#7D4F6D"
            },
            {
               value: 8,
               color: "#584A5E"
            }
         ]
      ]

      $scope.options = {
         segmentShowStroke: false
      }
   }
})
