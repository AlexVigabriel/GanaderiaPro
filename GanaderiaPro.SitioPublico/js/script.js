// URL de la app Flutter. En desarrollo local corre en este puerto con
// `flutter run -d web-server --web-port=8090`. Para un despliegue real,
// cambiar este único valor por la URL pública de la app.
const APP_BASE_URL = 'http://localhost:8090/#';

document.querySelectorAll('[data-ruta]').forEach((enlace) => {
  enlace.href = APP_BASE_URL + enlace.dataset.ruta;
});

// HU-02: en móvil, el menú del encabezado se despliega en formato hamburguesa.
const menuToggle = document.getElementById('menuToggle');
const menu = document.getElementById('menu');

menuToggle.addEventListener('click', () => {
  const abierto = menu.classList.toggle('menu-abierto');
  menuToggle.setAttribute('aria-expanded', abierto ? 'true' : 'false');
});

// Cierra el menú móvil al elegir una opción, para que se vea la sección.
menu.querySelectorAll('a').forEach((enlace) => {
  enlace.addEventListener('click', () => {
    menu.classList.remove('menu-abierto');
    menuToggle.setAttribute('aria-expanded', 'false');
  });
});
