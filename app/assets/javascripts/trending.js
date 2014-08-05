var trendingModule = angular.module('trending', []);

trendingModule.factory('Trending', function() {
  return {};
});

trendingModule.controller('TrendingCtrl', function($scope, Trending) {

  $scope.init = function() {
    var source = new EventSource('/trending');
    source.onmessage = function(event) {
      $scope.$apply(function () {
      	$scope.eventData = JSON.parse(event.data)
        $scope.tweet_data = $scope.eventData.tweet_data
      });
    };
  };

});