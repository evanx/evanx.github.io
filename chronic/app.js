/*
 Source https://code.google.com/p/vellum by @evanxsummers

 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements. See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership. The ASF licenses this file to
 you under the Apache License, Version 2.0 (the "License").
 You may not use this file except in compliance with the
 License. You may obtain a copy of the License at:

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.  
 */

var app = angular.module("app", ['ngSanitize', 'angles', 'ui.bootstrap']);

app.factory("personaService", ["$http", "$q", function($http, $q) {
        return {
            login: function(assertion) {
                var deferred = $q.defer();
                $http.post("/chronicapp/personaLogin", {
                    assertion: assertion,
                    timezoneOffset: (-new Date().getTimezoneOffset() / 60)
                }).then(function(response) {
                    if (response.errorMessage) {
                        console.warn("personaService login", response.errorMessage);
                        deferred.reject(response.errorMessage);
                    } else {
                        console.log("personaService login", response.data.email);
                        deferred.resolve(response.data);
                    }
                });
                return deferred.promise;
            },
            logout: function(email) {
                return $http.post("/chronicapp/personaLogout", {
                    email: email
                }).then(function(response) {
                    if (response.errorMessage) {
                        console.warn("personaService logout", response.errorMessage);
                    } else {
                        console.log("personaService logout", response);
                    }
                    return response.data;
                });
            }
        };
    }]);

app.controller("personaController", ["$scope", "$location", "personaService",
    function($scope, $location, personaService) {
        $scope.login = function() {
            console.log("persona login");
            $scope.view = 'about';
            navigator.id.request();
        };
        $scope.logout = function() {
            console.log("persona logout");
            navigator.id.logout();
        };
        $scope.changeView = function(view) {
            console.log("persona changeView", view);
            $scope.view = view;
            //$location.path("/" + view);
            $scope.$broadcast("changeView", view);
        };
        $scope.getClass = function(path) {
            if ($scope.view === path) {
                return "active";
            } else {
                return "";
            }
        };
        var persona = localStorage.getItem("persona");
        var loggedInUser = null;
        if (persona === null) {
            $scope.persona = {};
        } else {
            try {
                $scope.persona = JSON.parse(persona);
                console.log("persona", $scope.persona.email, $scope.persona.assertion.substring(0, 10));
                loggedInUser = $scope.persona.email;
                personaService.login($scope.persona.assertion).then(function(persona) {
                    $scope.persona = persona;
                    if (persona.email) {
                        localStorage.setItem("persona", JSON.stringify(persona));
                        $scope.$broadcast("loggedIn", persona.email);
                    } else {
                        console.warn("login", persona);
                        localStorage.clear("persona");
                    }
                });
            } catch (e) {
                console.log(e);
            }
        }
        navigator.id.watch({
            loggedInUser: loggedInUser,
            onlogin: function(assertion) {
                $scope.loggingIn = true;
                $scope.view = 'about';
                personaService.login(assertion).then(function(response) {
                    $scope.loggingIn = false;
                    $scope.persona = response;
                    if (response.email) {
                        localStorage.setItem("persona", JSON.stringify($scope.persona));
                        $scope.$broadcast("loggedIn", response.email);
                    } else {
                        console.warn("login", response);
                    }
                });
            },
            onlogout: function(response) {
                if ($scope.persona) {
                    if ($scope.persona.email) {
                        personaService.logout($scope.persona.email);
                    } else {
                        console.warn("logout", response);
                    }
                    $scope.persona = {};
                }
                localStorage.clear("persona");
            }
        });
    }]);

app.controller("topicEventsController", ["$scope", "$http",
    function($scope, $http) {
        $scope.loading = false;
        $scope.errorMessage = undefined;
        $scope.topicEventList = function() {
            console.log("topicEvents", $scope.persona.email);
            $scope.topicEvents = undefined;
            $scope.selected = undefined;
            $scope.errorMessage = undefined;
            $scope.loading = true;
            $http.post("/chronicapp/topicEventList", {
                email: $scope.persona.email
            }).then(function(response) {
                $scope.loading = false;
                console.log("topicEvents", response.data);
                if (response.data && response.data.topicEvents) {
                    $scope.topicEvents = response.data.topicEvents;
                } else if (response.data.errorMessage) {
                    $scope.errorMessage = response.data.errorMessage;
                } else {
                    console.warn("topicEvents", response);
                }
                console.log("topicEvents", $scope.view, $scope.loading, $scope.topicEvents.length);
            });
        };
        $scope.setSelected = function() {
            $scope.selected = this.topicEvent;
            console.log("selected", $scope.selected);
        };
        $scope.$on("loggedIn", function(email) {
            console.log("loggedIn", email);
        });
        $scope.$on("changeView", function(event, view) {
            if (view === "topicEvents") {
                $scope.topicEventList();
            } else {
                $scope.topicEvents = undefined;
                $scope.loading = false;
            }
        });
    }]);

app.controller("topicsController", ["$scope", "$http",
    function($scope, $http) {
        $scope.loading = false;
        $scope.actionAllDisabled = $scope.persona.demo;
        $scope.actionNoneDisabled = $scope.persona.demo;
        $scope.topicsList = function() {
            console.log("topics", $scope.persona.email);
            $scope.topics = undefined;
            $scope.selected = undefined;
            $scope.loading = true;
            $http.post("/chronicapp/topicList", {
                email: $scope.persona.email
            }).then(function(response) {
                $scope.loading = false;
                console.log("topics", response.data);
                if (response.data && response.data.topics) {
                    $scope.topics = response.data.topics;
                } else {
                    console.warn("topics", response);
                }
            });
        };
        $scope.actionAll = function() {
            console.log("actionAll");
            $http.post("/chronicapp/topicActionAll", {
            }).then(function(response) {
                if (response.data && response.data.topics) {
                    $scope.topics = response.data.topics;
                } else {
                    console.warn("topicActionAll", response);
                }
            });
        };
        $scope.actionNone = function() {
            console.log("actionNone");
            $http.post("/chronicapp/topicActionNone", {
            }).then(function(response) {
                if (response.data && response.data.topics) {
                    $scope.topics = response.data.topics;
                } else {
                    console.warn("topicActionNone", response);
                }
            });
        };
        $scope.action = function() {
            $scope.selected = this.topic;
            console.log("action", $scope.selected);
            $http.post("/chronicapp/topicAction", {
                "topic": $scope.selected
            }).then(function(response) {
                if (response.data && response.data.topic) {
                    $scope.selected.actionLabel = response.data.topic.actionLabel;
                } else {
                    console.warn("topicAction", response);
                }
            });
        };
        $scope.setSelected = function() {
            $scope.selected = this.topic;
            console.log("selected", $scope.selected);
        };
        $scope.$on("changeView", function(topicEvent, view) {
            if (view === "topics") {
                $scope.topicsList();
            } else {
                $scope.topics = undefined;
                $scope.loading = false;
            }
        });
    }]);

app.controller("subscriptionsController", ["$scope", "$http",
    function($scope, $http) {
        $scope.loading = false;
        $scope.actionAllDisabled = $scope.persona.demo;
        $scope.actionNoneDisabled = $scope.persona.demo;
        $scope.subscriptionsList = function() {
            console.log("subscriptions", $scope.persona.email);
            $scope.subscriptions = undefined;
            $scope.selected = undefined;
            $scope.loading = true;
            $http.post("/chronicapp/subscriptionList", {
                email: $scope.persona.email
            }).then(function(response) {
                $scope.loading = false;
                console.log("subscriptions", response.data);
                if (response.data && response.data.subscriptions) {
                    $scope.subscriptions = response.data.subscriptions;
                    $scope.subscriptions = response.data.subscriptions;
                } else {
                    console.warn("subscriptions", response);
                }
            });
        };
        $scope.actionAll = function() {
            console.log("actionAll");
            $http.post("/chronicapp/subscriptionActionAll", {
            }).then(function(response) {
                if (response.data && response.data.subscriptions) {
                    $scope.subscriptions = response.data.subscriptions;
                } else {
                    console.warn("subscriptionActionAll", response);
                }
            });
        };
        $scope.actionNone = function() {
            console.log("actionNone");
            $http.post("/chronicapp/subscriptionActionNone", {
            }).then(function(response) {
                if (response.data && response.data.subscriptions) {
                    $scope.subscriptions = response.data.subscriptions;
                } else {
                    console.warn("subscriptionActionNone", response);
                }
            });
        };
        $scope.action = function() {
            $scope.selected = this.subscription;
            console.log("action", $scope.selected);
            $http.post("/chronicapp/subscriptionAction", {
                "subscription": $scope.selected
            }).then(function(response) {
                if (response.data && response.data.subscription) {
                    console.warn("subscriptionAction", response.data.subscription.actionLabel);
                    $scope.selected.actionLabel = response.data.subscription.actionLabel;
                } else {
                    console.warn("subscriptionAction", response);
                }
            });
        };
        $scope.setSelected = function() {
            $scope.selected = this.subscription;
            console.log("selected", $scope.selected);
        };
        $scope.$on("changeView", function(event, view) {
            if (view === "subscriptions") {
                $scope.subscriptionsList();
            } else {
                $scope.subscriptions = undefined;
                $scope.loading = false;
            }
        });
    }]);

app.controller("rolesController", ["$scope", "$http",
    function($scope, $http) {
        $scope.loading = false;
        $scope.actionAllDisabled = $scope.persona.demo;
        $scope.actionNoneDisabled = $scope.persona.demo;
        $scope.rolesList = function() {
            console.log("roles", $scope.persona.email);
            $scope.roles = undefined;
            $scope.selected = undefined;
            $scope.loading = true;
            $http.post("/chronicapp/roleList", {
                email: $scope.persona.email
            }).then(function(response) {
                $scope.loading = false;
                console.log("roles", response.data);
                if (response.data && response.data.roles) {
                    $scope.roles = response.data.roles;
                } else {
                    console.warn("roles", response);
                }
            });
        };
        $scope.actionAll = function() {
            console.log("actionAll");
            $http.post("/chronicapp/roleActionAll", {
            }).then(function(response) {
                if (response.data && response.data.roles) {
                    $scope.roles = response.data.roles;
                } else {
                    console.warn("roleActionAll", response);
                }
            });
        };
        $scope.action = function() {
            $scope.selected = this.role;
            console.log("action", $scope.selected);
            $http.post("/chronicapp/roleAction", {
                "role": $scope.selected
            }).then(function(response) {
                if (response.data && response.data.role) {
                    console.warn("roleAction", response.data.role.actionLabel);
                    $scope.selected.actionLabel = response.data.role.actionLabel;
                } else {
                    console.warn("roleAction", response);
                }
            });
        };
        $scope.setSelected = function() {
            $scope.selected = this.role;
            console.log("selected", $scope.selected);
        };
        $scope.$on("changeView", function(event, view) {
            if (view === "roles") {
                $scope.rolesList();
            } else {
                $scope.roles = undefined;
            }
        });
    }]);

app.controller("certsController", ["$scope", "$http",
    function($scope, $http) {
        $scope.actionAllDisabled = $scope.persona.demo;
        $scope.actionNoneDisabled = $scope.persona.demo;
        $scope.loading = false;
        $scope.certsList = function() {
            console.log("certs", $scope.persona.email);
            $scope.certs = undefined;
            $scope.loading = true;
            $scope.selected = undefined;
            $http.post("/chronicapp/certList", {
                email: $scope.persona.email
            }).then(function(response) {
                $scope.loading = false;
                console.log("certs", response.data);
                if (response.data && response.data.certs) {
                    $scope.certs = response.data.certs;
                } else {
                    console.warn("certs", response);
                    //navigator.id.logout();
                }
            });
        };
        $scope.actionAll = function() {
            console.log("actionAll");
            $scope.loading = true;
            $scope.certs = undefined;
            $http.post("/chronicapp/certActionAll", {
            }).then(function(response) {
                if (response.data && response.data.certs) {
                    $scope.certs = response.data.certs;
                } else {
                    console.warn("certActionAll", response);
                }
            });
        };
        $scope.action = function() {
            $scope.selected = this.cert;
            console.log("action", $scope.selected);
            $http.post("/chronicapp/certAction", {
                "cert": $scope.selected
            }).then(function(response) {
                if (response.data && response.data.cert) {
                    $scope.selected.actionLabel = response.data.cert.actionLabel;
                } else {
                    console.warn("certAction", response);
                }
            });
        };
        $scope.setSelected = function() {
            $scope.selected = this.cert;
            console.log("selected", $scope.selected);
            $http.post("/chronicapp/certAction", {
                "cert": $scope.selected
            }).then(function(response) {
                if (response.data && response.data.cert) {
                    $scope.selected.actionLabel = response.data.cert.actionLabel;
                } else {
                    console.warn("certAction", response);
                }
            });
        };
        $scope.$on("changeView", function(event, view) {
            if (view === "certs") {
                $scope.certsList();
            } else {
                $scope.certs = undefined;
                $scope.loading = false;
            }
        });
    }]);

app.controller("chartController", function($scope, $http) {

    $scope.interval = "MINUTELY";
    
    $http.post("/chronicapp/intervalList", {
    }).then(function(response) {
        if (response.data && response.data.intervals) {
            $scope.intervals = response.data.intervals;
        } else {
            console.warn("intervalList", response);
        }
    });

    $scope.intervalChanged = function(value) {
        console.log("intervalChanged", value);
        $scope.interval = value;
        $scope.chartList();
    };

    $scope.chartList = function() {
        console.log("chartList");
        $scope.charts = undefined;
        $scope.metrics = undefined;
        $scope.selected = undefined;
        $scope.loading = true;
        $http.post("/chronicapp/chartList", {
            data: $scope.interval
        }).then(function(response) {
            $scope.loading = false;
            $scope.charts = undefined;
            if (response.data && response.data.metrics) {
                $scope.metrics = response.data.metrics;
                console.log("metrics", response.data.metrics.length, response.data.metrics.length);
                if ($scope.metrics.length > 0) {
                    console.log("metrics first length", response.data.metrics[0].data.length, response.data.metrics[0].labels.length);
                }
                $scope.renderCharts();
            } else {
                console.warn("metrics", response);
            }
        });
    };

    $scope.renderCharts = function() {
        var charts = [];
        console.log("renderCharts", $scope.metrics.length);
        for (var i = 0; i < $scope.metrics.length; i++) {
            var metrics = $scope.metrics[i];
            var chart = {
                commonName: metrics.commonName,
                topicLabel: metrics.topicLabel,
                metricLabel: metrics.metricLabel,
                labels: metrics.labels,
                datasets: [{
                        fillColor: "rgba(151,187,205,0)",
                        strokeColor: "#e67e22",
                        pointColor: "rgba(151,187,205,0)",
                        pointStrokeColor: "#e67e22",
                        data: metrics.data
                    }
                ]
            };
            charts.push(chart);
        }
        $scope.charts = charts;
    };

    $scope.options = {
        pointDotRadius: 1,
        pointDotStrokeWidth: 1,
        scaleShowLabels: true,
        scaleOverlay: false,
        scaleOverride: false,
        scaleSteps: 3,
        scaleStepWidth: 2,
        scaleStartValue: 0,
        segmentShowStroke: false
    };

    $scope.$on("changeView", function(event, view) {
        if (view === "charts") {
            $scope.chartList();
        } else {
            $scope.loading = false;
            $scope.charts = undefined;
        }
    });

})
