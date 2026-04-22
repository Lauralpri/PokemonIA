# 📱 Pokédex App – iOS (SwiftUI)

Aplicación iOS desarrollada en **SwiftUI** que consume la API pública de Pokémon:

👉 https://pokeapi.co/api/v2/pokemon

El proyecto implementa listado, navegación a detalle, manejo completo de estados, paginación, control de errores con reintento y mejoras visuales premium.

---

# 🚀 Funcionalidades implementadas

## ✅ 1. Consumo de API real
- Endpoint: `GET https://pokeapi.co/api/v2/pokemon?limit=&offset=`
- Obtención de:
  - Imagen
  - Nombre
  - ID
  - Tipos
  - Altura
  - Peso

---

## ✅ 2. Listado de Pokémon
- Imagen + nombre + ID visible
- LazyVStack optimizada
- Paginación controlada (3 páginas mínimo)
- Indicador visual de página
- Botones de navegación con animación

---

## ✅ 3. Navegación a detalle
- NavigationStack
- Transición hero usando `matchedGeometryEffect`
- Animación escalonada al cargar el detalle:
  - Imagen
  - Nombre
  - Tipos
  - Altura y peso

---

## ✅ 4. Manejo completo de estados

### En listado:
- `idle`
- `loading`
- `loaded`
- `empty`
- `error`

### En detalle:
- `idle`
- `loading`
- `loaded`
- `error`

---

## ✅ 5. Control de errores (requisito obligatorio)

Simulación de error mediante modo avión:

1. Activar modo avión en el simulador.
2. Intentar cargar listado o detalle.
3. Se muestra pantalla de error.
4. Botón **Reintentar** disponible.
5. Desactivar modo avión.
6. Pulsar Reintentar.
7. La petición se vuelve a ejecutar correctamente.

✔ No hay crash  
✔ Retry funcional  
✔ Estado correctamente gestionado  

---

## ✅ 6. Dark Mode / Light Mode manual

- Toggle en la parte superior.
- Persistencia con `@AppStorage`.
- Adaptación de colores y sombras.
- Contraste correcto en ambos modos.

---

## ✅ 7. Arquitectura aplicada

Separación por capas siguiendo enfoque tipo Clean Architecture:

### Core
- HTTPClient
- Implementación URLSession

### Features
- PokemonList
  - Data (DTOs, Repository)
  - Domain (UseCase)
  - Presentation (View + ViewModel)
- PokemonDetail
  - Data
  - Domain
  - Presentation

Separación clara entre:
- DTO
- Model de dominio
- Use Case
- ViewModel
- Vista

---

# 🧪 Cómo probar los errores

En el simulador iOS:

1. Abrir Ajustes → Activar modo avión.
2. Entrar a un Pokémon.
3. Se mostrará pantalla de error.
4. Desactivar modo avión.
5. Pulsar "Reintentar".
6. La información se carga correctamente.

---

# 🎨 Mejoras visuales implementadas

- Diseño premium centrado.
- Gradientes modernos.
- Transiciones suaves.
- Hero animation entre lista y detalle.
- Animación escalonada en detalle.
- Indicador visual de página.
- Botones con feedback visual.

---

# 🛠 Tecnologías utilizadas

- Swift 5
- SwiftUI
- Async/Await
- URLSession
- Combine
- PokeAPI

---

# 📌 Requisitos cumplidos

✔ Consumo de API real  
✔ Estados (loading / error / empty)  
✔ Paginación mínima 3 páginas  
✔ Navegación lista → detalle  
✔ Manejo de error con reintento  
✔ No crash en modo avión  
✔ Datos reales mostrados  

---

# 👨‍💻 Autor

Proyecto académico desarrollado como práctica completa de consumo de API y gestión de estados en iOS.

---

# ✅ Estado final del proyecto

La aplicación está completamente funcional y cumple todos los requisitos técnicos solicitados, incluyendo control de errores, reintento exitoso y arquitectura modular.
