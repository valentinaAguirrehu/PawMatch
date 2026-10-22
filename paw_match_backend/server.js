require('dotenv').config();
const express = require('express');
const cors = require('cors');
const usuariosRoutes = require('./routes/usuarios');
const adminUsuariosRoutes = require('./routes/admin_usuarios');
const mascotasRoutes = require('./routes/mascotas');
const fundacionRoutes = require('./routes/fundacion');
const solicitudesApadrinamientoRoutes = require('./routes/solicitudes_apadrinamiento');
const adoptionRequestsRoutes = require('./routes/adoption_requests');
const noticiasRoutes = require('./routes/noticias');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/usuarios', usuariosRoutes);
app.use('/api/admin/usuarios', adminUsuariosRoutes);
app.use('/api/mascotas', mascotasRoutes);
app.use('/api/fundacion', fundacionRoutes);
app.use('/api/solicitudes-apadrinamiento', solicitudesApadrinamientoRoutes);
app.use('/api/adoption-requests', adoptionRequestsRoutes);
app.use('/api/noticias', noticiasRoutes);
app.use('/uploads', express.static('uploads'));

app.get('/', (req, res) => res.send('API Paw Match funcionando'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});
