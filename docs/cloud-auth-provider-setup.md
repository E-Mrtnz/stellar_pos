# Configuración de proveedores de autenticación en la nube

La pantalla de STELLAR POS ya incluye correo/contraseña, Google, Apple y teléfono. Los métodos externos también necesitan habilitarse en Firebase y registrar las credenciales propias de cada plataforma; el código del repositorio no puede activar esas opciones por sí solo.

## Firebase Console

1. Abre el proyecto Firebase que usa esta rama y entra en **Authentication → Sign-in method**.
2. Habilita **Email/Password**, **Google**, **Apple** y **Phone** según los métodos que quieras ofrecer.
3. En **Settings → Authorized domains**, confirma que el dominio donde se aloja la versión web esté autorizado.
4. Para Phone, revisa las cuotas y añade números de prueba durante el desarrollo para evitar SMS reales repetidos.

## Google en Android e iOS

- Registra el SHA-1 y SHA-256 de la clave de firma de Android en la app Android de Firebase.
- En Firebase, habilita Google y descarga de nuevo `google-services.json` para incluir los clientes OAuth generados. El archivo actualmente versionado no contiene clientes OAuth.
- Para iOS, configura el ID de cliente OAuth de iOS y el esquema URL inverso que Google proporciona en la configuración de Firebase/Google. Verifica que coincida con el Bundle ID de Runner.
- Tras cambiar los archivos de configuración, ejecuta `flutter pub get` y vuelve a compilar la plataforma.

## Apple

- Habilita Apple como proveedor en Firebase Authentication y completa los datos requeridos por Apple (Team ID, Key ID, clave privada y Services ID cuando corresponda).
- En Apple Developer, habilita la capacidad **Sign in with Apple** para el identificador de la app.
- En Xcode, añade la capacidad y los entitlements correspondientes a los targets iOS/macOS que se vayan a distribuir. La disponibilidad depende de las capacidades y configuración de cada plataforma.

## Pruebas

La prueba automatizada del repositorio cubre el flujo de interfaz de teléfono usando un gateway falso. Para verificar el envío real de SMS, Google y Apple se deben realizar pruebas manuales con las credenciales de Firebase/Apple configuradas. No publiques credenciales privadas ni claves privadas en el repositorio.
