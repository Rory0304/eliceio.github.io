---
layout: post
title:  "Progressive Web App (2)"
author: "Suin Kim"
date:   2021-10-24 18:10:00 +0900
categories: JavaScript
---

[Progressive Web App 1편](/javascript/2021/08/30/progressive-web-app.html)에서는 PWA와 service worker가 무엇이고 어떻게 동작하는지, PWA의 장/단점은 무엇인지 알아보았습니다. 2편에서는 실제로 React 기반 웹 사이트에 PWA를 적용하는 방법을 알아보겠습니다.

PWA를 설정하는 가장 쉬운 방법은 Create React App (CRA)을 사용하는 것입니다. CRA의 커스텀 템플릿 기능을 사용해 PWA가 이미 세팅된 상태로 동작하는 앱을 시작할 수 있습니다.

```sh
# JavaScript  
npx create-react-app my-app --template cra-template-pwa

# TypeScript  
npx create-react-app my-app --template cra-template-pwa-typescript
```

해당 템플릿에는 몇 가지 설정이 되어 있는데, Google의 [Workbox](https://developers.google.com/web/tools/workbox) 가 Webpack 과 같이 동작하게 미리 세팅되어 있어 React 앱을 빌드할 때 생성되는 bundle 들을 service worker 가 precache 할 수 있게 해줍니다. 이번 포스트에서는 TypeScript 기준으로 만들어진 코드를 분석해보도록 하겠습니다.

service-worker.ts
-----------------

`service-worker.ts` 파일은 Service Worker 가 작성되는 파일로 프로젝트의 빌드 후 `process.env.PUBLIC_URL/service-worker.js` 로 transpile 된 버전이 액세스 가능하게 됩니다. 이 파일은 표준 API를 사용하지 않고 Google의 Workbox 를 이용하여 작성되어 기존 service worker의 복잡한 lifecycle 을 모두 이해하지 않아도 쉽게 파일을 수정할 수 있습니다. 이 파일에서 가장 중요한 부분은 `precacheAndRoute`, `registerRoute` 함수입니다.

```ts
precacheAndRoute(self.__WB_MANIFEST);  
...registerRoute(  
  ({ request, url }: { request: Request; url: URL }) => {  
    ... },  
  createHandlerBoundToURL(process.env.PUBLIC_URL + '/index.html')  
);
```

`precacheAndRoute` 함수는 `workbox-precaching` 패키지에서 가져오게 되며 파라미터로 주어진 path 의 엔트리들을 precache 리스트에 넣어 캐싱을 진행하고, 캐싱이 진행된 path 에 대해 라우팅이 일어날 경우 이에 응답하는 것을 처리합니다. 여기에 들어있는 `self.__WB_MANIFEST` 는 빌드 전에 특별한 값을 가지고 있는 것은 아니고 Webpack 이 service-worker.js 파일을 만들 때 참고하는 placeholder 입니다. CRA에는 이미 설정이 되어 있지만, 이것을 수동하는 코드는 참고로 다음과 같습니다.

```js
// webpack.config.js
const WorkboxPlugin = require('workbox-webpack-plugin');  
  
module.exports = {  
  ...
  plugins: [  
    ...
    new WorkboxPlugin.InjectManifest({  
      swSrc: './src/service-worker.ts',  
      swDest: 'service-worker.js',  
    }),  
  ],  
};
```

`registerRoute` 함수는 Regex, string, 혹은 함수와 handler 를 입력받아 원하는 asset이나 path, 파일에 따라 원하는 방식의 캐싱을 설정할 수 있습니다. 여기에서 설정할 수 있는 캐싱 방식은 [workbox-strategies 플러그인](https://developers.google.com/web/tools/workbox/modules/workbox-strategies#stale-while-revalidate)에서 정의된 5가지 방식이 가능합니다:

*   Stale-While-Revalidate: 만약 캐싱된 response가 있다면 이것으로 바로 응답하고, 만약 그렇지 않다면 network request 로 fallback이 일어납니다. 캐싱된 response로 응답이 일어난 뒤에 network request가 백그라운드에서 캐시의 업데이트를 수행합니다. 가장 기본적으로 많이 사용되는 옵션입니다.
*   Cache First: 업데이트가 자주 수행되지 않아도 되는 static asset 을 위해 많이 사용되며, Stale-While-Revalidate 와는 달리 캐싱이 되어 있는 경우 바로 응답하고 캐시의 업데이트를 수행하지 않습니다.
*   Network First: 자주 업데이트가 수행되고 항상 최신 데이터를 가져오는 것이 중요한 자료에 대해 수행하며, 네트워크에서 최신 데이터를 받아오는 것을 우선적으로 수행하며, 이것이 실패할 경우 캐시된 데이터를 응답합니다.
*   Network Only: 캐싱을 전혀 사용하지 않고 네트워크 자원만 사용합니다.
*   Cache Only: 거의 사용되지 않으며, 응답을 캐시에서만 받아오도록 설정합니다. Precaching 이 수동으로 진행되는 경우에만 의미가 있습니다.

serviceWorkerRegistration.ts
----------------------------

Service worker를 등록하고 그 뒤의 이벤트를 동시에 처리할 수 있습니다. PWA가 적용된 웹앱의 경우 캐시 주기에 대해 주의할 필요가 있습니다. 기존 React App 을 개발하던 개발자가 실수를 하기 쉬운 부분은, PWA는 같은 사이트에 대해 여러 앱이 동시에 열려 있는 경우 한 **탭에서 새로고침을 해도 새로운 앱이 로드되지 않는다는 것입니다**.

이 행동은 [Create React App의 PWA 문서](https://create-react-app.dev/docs/making-a-progressive-web-app/#offline-first-considerations) 중 Offline-First Considerations 섹션에 자세히 설명되어 있는데, Service worker는 범위 내 페이지가 모두 동일한 SW로 제어되어야 하기 때문에, 한 번에 한 버전의 사이트만 실행되며, 따라서 동일한 웹 사이트가 여러 탭 혹은 여러 윈도우에 걸쳐서 실행 중이라면 한 탭에서 새로고침을 해도 새로운 웹앱을 다운로드 받을 수 없다는 것입니다.

이런 경우에는 Service Worker의 새로운 버전이 로드되었고 설치되었더라도 `WAITING` state에서 모든 웹앱이 종료될때까지 대기하게 되며, 사용자는 새 버전을 실행할 수 없게 됩니다. 이러한 정책은 탭 간의 앱의 consistency 를 지키는데에는 잘 작동하지만, 웹앱에 버그가 있어 빠르게 핫픽스를 진행해야 하는 상황에서는 유저가 새로고침이라는 직관적인 행동을 하더라도 버그가 있는 기존 웹앱이 계속 로드되는 심각한 문제가 발생하게 됩니다.

![PWA를 사용하면 유저에게 새 버전 알림을 진행하고, 탭 간 버전의 consistency도 유지할 수 있습니다.](https://cdn-api.elice.io/api-attachment/attachment/a56434d67814443d95c9a2c761df0dc1/image.png)

이를 해결하기 위해서는 버그를 해결하는 소프트웨어가 릴리즈된 직후,

*   새로운 릴리즈가 일어났음을 발견
*   이 기쁜 소식을 유저에게 알림
*   동시에 새로운 SW를 백그라운드에서 설치
*   새로운 SW의 activate
*   새로운 SW를 사용한 웹앱을 로드하기 위해 새로고침

총 다섯 단계가 필요합니다.

새로운 릴리즈가 일어났음을 발견
-----------------

이것을 하기 위한 여러 방법이 있는데, 주기적으로 service worker의 새 버전을 체크하거나, React와 같은 SPA에서는 history에서 새로운 location이 업데이트 될 때마다 실행되는 callback 이벤트에서 업데이트를 체크할 수 있습니다. 아래 코드는, 유저가 React SPA에서 새로운 페이지로 내비게이션을 진행할 때, 브라우저에 등록된 (모든) service worker 에 대해 업데이트를 수동으로 실행하는 것입니다.

```ts
history.listen((location, action) => {  
  if (!navigator.serviceWorker) {  
    return;  
  }  
  navigator.serviceWorker.getRegistrations().then(regs =>  
    regs.forEach(reg => {  
      reg.update().catch(e => {  
        // Fetching SW failed.  
      });  
    })  
  );  
});
```

만약 새로운 service worker (새로운 릴리즈) 가 발견되었다면, 해당 이벤트는 `serviceWorkerRegistration.ts` 내의 `registration.onupdatefound` 에서 handle 할 수 있습니다.

```ts
function registerValidSW(swUrl: string, config?: Config) {  
  navigator.serviceWorker  
    .register(swUrl)  
    .then(registration => {  
      registration.onupdatefound = () => {  
        ...  
      }  
  ...
```

유저에게 알림
-------

`registration.installingWorker` 는 현재 설치되고 있는/설치된 SW를 의미하며, 이것의 state가 `installed` 라면 새로운 SW가 발견된 후 설치까지 완료되어 activate를 기다리고 있는 상태입니다. 유저에게는 이 때 팝업을 띄워줄 수 있습니다. 엘리스에는 다음과 같은 코드가 적용되어 있습니다.

```ts
const installingWorker = registration.installing;  
  if (installingWorker == null) {  
    return;  
  }  
  installingWorker.onstatechange = () => {  
    if (installingWorker.state === 'installed') {  
      if (navigator.serviceWorker.controller) {  
        doShowSWUpdateToast();  
        ...  
      }  
    ...
```

새로운 SW의 설치
----------

위 코드에서 보여진 Toast 에서 유저가 새로고침 버튼을 누른다면, 다음 코드로 새로 설치된 service worker를 강제로 activate 시킬 수 있습니다. 아래 코드는, 현재 브라우저에 설치된 service worker 중 상태가 `waiting` 인 것에 한하여 `SKIP_WAITING` 메시지를 전송하는 것입니다.

```ts
navigator.serviceWorker.getRegistrations().then(regs =>  
  regs.forEach(reg => {  
    reg?.waiting?.postMessage({ type: 'SKIP_WAITING' });  
  })  
);
```

새로 고침
-----

마지막으로 새로운 service worker가 설치되었음을 알리고, 새로고침을 진행하면 유저는 새 버전의 웹앱을 사용할 수 있습니다.

기존 React App에 적용
================

위 모든 사항은 사용자가 새로운 React App을 CRA 기반으로 새로 작성할 때를 기준으로 만들어졌습니다. 기존 React App 이 있다면 이것을 적용하는 것은 대단히 쉽습니다.

*   service-worker.ts 파일을 복사
*   serviceWorkerRegistration.ts 파일을 복사
*   index.tsx 에 `serviceWorkerRegistration.register()` 구문을 추가
*   Webpack 설정이 필요하다면 진행, CRA 기반이라면 필요 없음

이러한 비교적 쉬운 단계로 PWA를 설정할 수 있습니다. 다음으로 작성할 마지막 포스트로는 서로 다른 라우팅에 적용한 캐싱 정책에 대해서 알아보겠습니다.