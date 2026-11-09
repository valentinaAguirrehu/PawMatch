const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const usuariosRoutes = require('./routes/usuarios');
const personalidadEntrevistaRoutes = require('./routes/personalidad_entrevista');
const adminUsuariosRoutes = require('./routes/admin_usuarios');
const mascotasRoutes = require('./routes/mascotas');
const fundacionRoutes = require('./routes/fundacion');
const solicitudesApadrinamientoRoutes = require('./routes/solicitudes_apadrinamiento');
const adoptionRequestsRoutes = require('./routes/adoption_requests');
const noticiasRoutes = require('./routes/noticias');
const pool = require('./db');
const { asegurarRolSuperAdmin } = require('./utils/roles');
const { asegurarGeneroUsuario } = require('./utils/genero_usuario');
const { asegurarVozAsistente } = require('./utils/voz_asistente');
const { asegurarEsquemaMatch } = require('./utils/match_persistencia');
const denunciasRoutes = require('./routes/denuncias');
const seguimientoApadrinamientoRoutes = require('./routes/seguimiento_apadrinamiento');
const seguimientoAdopcionRoutes = require('./routes/seguimiento_adopcion');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/usuarios', personalidadEntrevistaRoutes);
app.use('/api/usuarios', usuariosRoutes);
app.use('/api/admin/usuarios', adminUsuariosRoutes);
app.use('/api/mascotas', mascotasRoutes);
app.use('/api/fundacion', fundacionRoutes);
app.use('/api/solicitudes-apadrinamiento', solicitudesApadrinamientoRoutes);
app.use('/api/seguimiento-apadrinamiento', seguimientoApadrinamientoRoutes);
app.use('/api/seguimiento-adopcion', seguimientoAdopcionRoutes);
app.use('/api/adoption-requests', adoptionRequestsRoutes);
app.use('/api/noticias', noticiasRoutes);
app.use('/api/denuncias', denunciasRoutes);
app.use(
  '/uploads',
  express.static(path.join(__dirname, 'uploads'), {
    maxAge: '7d',
    immutable: true,
    etag: true,
  }),
);

app.get('/', (req, res) => res.send('API Paw Match funcionando'));

const PORT = process.env.PORT || 3000;
asegurarRolSuperAdmin(pool).catch((error) => {
  console.error('No se pudo preparar el rol superadmin:', error.message);
});
asegurarGeneroUsuario(pool).catch((error) => {
  console.error('No se pudo preparar el género del usuario:', error.message);
});
asegurarVozAsistente(pool).catch((error) => {
  console.error('No se pudo preparar la voz del asistente:', error.message);
});
asegurarEsquemaMatch().catch((error) => {
  console.error('No se pudo preparar el esquema de Match:', error.message);
});
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});
