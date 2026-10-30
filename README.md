# Inventario Tiendas

Aplicación de escritorio para Windows, hecha con Flutter y SQLite, para llevar el inventario de un negocio. Cada instalación corresponde a una sede y guarda sus datos en ese equipo.

## Estado

| Módulo | Estado |
| --- | --- |
| Categorías | Listo |
| Productos | Listo |
| Inventario (entradas, salidas, ajustes e historial) | Listo |
| Proveedores | Listo |
| Login, Dashboard, Ventas, Reportes | Pendiente |

## Comandos

```
flutter pub get
flutter run -d windows
flutter test
flutter analyze
```

## Datos

- La base de datos está en `%APPDATA%\InventarioTiendas\inventario_tiendas\inventario.db`.
- El dinero se guarda en centavos y las cantidades en milésimas, siempre como enteros.
- Los productos no se borran, se desactivan, para conservar su historial.
- El stock solo cambia mediante movimientos registrados en `stock_movements`.
- Los cambios al esquema se hacen con una migración nueva en `lib/core/database/app_database.dart`.
