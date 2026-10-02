// URL de la app Flutter. En desarrollo local corre en este puerto con
// `flutter run -d web-server --web-port=8090`. Para un despliegue real,
// cambiar este único valor por la URL pública de la app.
const APP_BASE_URL = 'http://localhost:8090/#';

// Las animaciones de aparición solo se activan si hay JavaScript: sin él,
// todo el contenido queda visible.
document.documentElement.classList.add('js');

document.querySelectorAll('[data-ruta]').forEach((enlace) => {
  enlace.href = APP_BASE_URL + enlace.dataset.ruta;
});

// --- Menú en celular (hamburguesa) ---
const menuToggle = document.getElementById('menuToggle');
const menu = document.getElementById('menu');

function cerrarMenu() {
  menu.classList.remove('menu-abierto');
  menuToggle.setAttribute('aria-expanded', 'false');
}

menuToggle.addEventListener('click', () => {
  const abierto = menu.classList.toggle('menu-abierto');
  menuToggle.setAttribute('aria-expanded', abierto ? 'true' : 'false');
});

menu.querySelectorAll('a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu));

// --- Menús desplegables (Funciones, Recursos) ---
// En computadora se abren al pasar el mouse (CSS); el clic sirve para
// pantallas táctiles y teclado.
const desplegables = document.querySelectorAll('.desplegable');

desplegables.forEach((desplegable) => {
  const boton = desplegable.querySelector('.boton-desplegable');
  boton.addEventListener('click', (evento) => {
    evento.stopPropagation();
    const abrir = !desplegable.classList.contains('abierto');
    desplegables.forEach((otro) => {
      otro.classList.remove('abierto');
      otro.querySelector('.boton-desplegable').setAttribute('aria-expanded', 'false');
    });
    desplegable.classList.toggle('abierto', abrir);
    boton.setAttribute('aria-expanded', abrir ? 'true' : 'false');
  });
  desplegable.querySelectorAll('.submenu a').forEach((enlace) =>
    enlace.addEventListener('click', () => desplegable.classList.remove('abierto')),
  );
});

document.addEventListener('click', () => {
  desplegables.forEach((desplegable) => {
    desplegable.classList.remove('abierto');
    desplegable.querySelector('.boton-desplegable').setAttribute('aria-expanded', 'false');
  });
});

// --- El encabezado toma fondo al bajar ---
const encabezado = document.getElementById('encabezado');
const actualizarEncabezado = () => encabezado.classList.toggle('con-fondo', window.scrollY > 24);
window.addEventListener('scroll', actualizarEncabezado, { passive: true });
actualizarEncabezado();

// --- Pestañas de "El sistema en acción" ---
const pestanas = document.querySelectorAll('.pestana');

pestanas.forEach((pestana) => {
  pestana.addEventListener('click', () => {
    pestanas.forEach((otra) => {
      const activa = otra === pestana;
      otra.classList.toggle('activa', activa);
      otra.setAttribute('aria-selected', activa ? 'true' : 'false');
      document.getElementById(otra.getAttribute('aria-controls')).hidden = !activa;
    });
  });
});

// --- Aparición de bloques al hacer scroll ---
const observadorRevelar = new IntersectionObserver(
  (entradas) => {
    entradas.forEach((entrada) => {
      if (entrada.isIntersecting) {
        entrada.target.classList.add('visible');
        observadorRevelar.unobserve(entrada.target);
      }
    });
  },
  { threshold: 0.12 },
);

document.querySelectorAll('[data-revelar]').forEach((bloque) => observadorRevelar.observe(bloque));

// --- Marca en el menú la sección que se está viendo ---
const enlacesSeccion = document.querySelectorAll('a.enlace-menu[href^="#"]');

const observadorSecciones = new IntersectionObserver(
  (entradas) => {
    entradas.forEach((entrada) => {
      if (!entrada.isIntersecting) return;
      enlacesSeccion.forEach((enlace) =>
        enlace.classList.toggle('activo', enlace.getAttribute('href') === `#${entrada.target.id}`),
      );
    });
  },
  { rootMargin: '-45% 0px -50% 0px' },
);

enlacesSeccion.forEach((enlace) => {
  const seccion = document.querySelector(enlace.getAttribute('href'));
  if (seccion) observadorSecciones.observe(seccion);
});
