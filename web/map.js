(function () {
  let map;
  let originMarker;
  let destinationMarker;
  let activeRoute;

  function removeObject(object) {
    if (map && object) map.geoObjects.remove(object);
  }

  window.navigatorMapInit = function (containerId, apiKey, onSelect, onReady, onError) {
    const script = document.createElement('script');
    script.src = `https://api-maps.yandex.ru/2.1/?apikey=${encodeURIComponent(apiKey)}&lang=ru_RU`;
    script.onload = function () {
      ymaps.ready(function () {
        map = new ymaps.Map(containerId, {
          center: [55.751244, 37.618423],
          zoom: 12,
          controls: ['zoomControl']
        });
        map.events.add('click', function (event) {
          const coordinates = event.get('coords');
          onSelect(coordinates[0], coordinates[1]);
        });
        onReady();
      });
    };
    script.onerror = function () {
      onError('Не удалось загрузить Яндекс Карты. Проверьте API-ключ и подключение к сети.');
    };
    document.head.appendChild(script);
  };

  window.navigatorMapLocate = function (onSuccess, onError) {
    if (!navigator.geolocation) {
      onError('Браузер не поддерживает определение местоположения.');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      function (position) {
        onSuccess(position.coords.latitude, position.coords.longitude);
      },
      function (error) {
        onError(error.message || 'Не удалось определить местоположение.');
      },
      { enableHighAccuracy: true, timeout: 15000 }
    );
  };

  window.navigatorMapSetOrigin = function (latitude, longitude) {
    removeObject(originMarker);
    originMarker = new ymaps.Placemark(
      [latitude, longitude],
      { iconCaption: 'Вы здесь' },
      { preset: 'islands#greenCircleDotIcon' }
    );
    map.geoObjects.add(originMarker);
    map.setCenter([latitude, longitude], 15, { duration: 250 });
  };

  window.navigatorMapSetDestination = function (latitude, longitude) {
    removeObject(destinationMarker);
    removeObject(activeRoute);
    activeRoute = null;
    destinationMarker = new ymaps.Placemark(
      [latitude, longitude],
      {},
      { preset: 'islands#redIcon' }
    );
    map.geoObjects.add(destinationMarker);
  };

  window.navigatorMapBuildRoute = function (fromLat, fromLon, toLat, toLon, onResult) {
    removeObject(activeRoute);
    ymaps.route([[fromLat, fromLon], [toLat, toLon]], { mapStateAutoApply: true })
      .then(
        function (route) {
          activeRoute = route;
          map.geoObjects.add(route);
          const duration = route.properties.get('duration');
          onResult(duration ? duration.text : '', route.getHumanLength(), '');
        },
        function (error) {
          onResult('', '', error.message || 'Сервис маршрутизации временно недоступен.');
        }
      );
  };
})();