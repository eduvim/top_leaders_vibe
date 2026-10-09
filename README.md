# Registro de situaciones emocionales

Aplicación web local (una sola persona, sin cuentas, sin nube) para registrar
situaciones emocionales mediante un formulario guiado de 5 preguntas y
revisarlas después. Desarrollada con Ruby on Rails **sin base de datos**: los
registros se guardan en un único archivo JSON en el escritorio del usuario.

> Esta aplicación es un registro personal de autoconocimiento. No sustituye la
> atención psicológica profesional.

## Requisitos

- Ruby 3.3+
- Rails 8.x (instalado en el Gemfile via Bundler)

## Instalación y ejecución

```sh
bundle config set --local path vendor/bundle   # solo la primera vez, si no eres root
bundle install
bin/rails server
```

Abre <http://localhost:3000>. La aplicación funciona completamente offline.

## Dónde se guardan los registros

Por defecto en `~/Desktop/emotional_situations.json` (decisión D6 de la
especificación). Puedes cambiar la ruta con la variable de entorno:

```sh
SITUATION_LOG_FILE=/ruta/absoluta/registros.json bin/rails server
```

El formato del archivo está especificado en
[`specs/001-emotional-situation-logging/contracts/storage-file.md`](specs/001-emotional-situation-logging/contracts/storage-file.md):
un wrapper `{"version": 1, "entries": [...]}` con escrituras atómicas. Nunca
se sobrescribe un archivo que no se pudo leer.

## Pruebas

```sh
bin/rails test           # modelos, repositorio, controladores, integración
bin/rails test:system    # flujo del formulario guiado
bin/rubocop              # estilo
```

Las pruebas SIEMPRE usan un archivo temporal (`SITUATION_LOG_FILE` apuntando a
un directorio temporal); nunca tocan tu archivo real del escritorio.

## Documentación de diseño

- Especificación: [`specs/001-emotional-situation-logging/spec.md`](specs/001-emotional-situation-logging/spec.md)
- Plan: [`specs/001-emotional-situation-logging/plan.md`](specs/001-emotional-situation-logging/plan.md)
- Guía de validación: [`specs/001-emotional-situation-logging/quickstart.md`](specs/001-emotional-situation-logging/quickstart.md)

## Estructura

- `app/models/situation_entry.rb` — modelo ActiveModel sin base de datos
  (validaciones D1–D4, normalización de etiquetas de emoción).
- `app/services/entry_repository.rb` — única componente que toca el archivo
  JSON (CRUD, escrituras atómicas).
- `app/controllers/entries_controller.rb` — formulario guiado, guardado,
  borradores, lista, detalle, edición y borrado.
- `config/initializers/situation_log.rb` — resolución de la ruta del archivo.
