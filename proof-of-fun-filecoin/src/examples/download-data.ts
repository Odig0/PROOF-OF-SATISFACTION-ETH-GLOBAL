/**
 * Ejemplo: Descargar datos de Filecoin usando PieceCID
 */

import { FilecoinStorageService } from '../FilecoinStorage.js';

async function main() {
  const storage = new FilecoinStorageService();

  try {
    await storage.initialize();

    // Reemplaza con tu PieceCID real
    const pieceCid = process.argv[2];

    if (!pieceCid) {
      console.error('\n❌ Uso: npm run example:download <PieceCID>\n');
      process.exit(1);
    }

    console.log(`\n📥 Descargando datos desde Filecoin...`);
    console.log(`   PieceCID: ${pieceCid}\n`);

    const data = await storage.download(pieceCid);

    console.log('\n✅ Datos descargados exitosamente!');
    console.log(JSON.stringify(data, null, 2));
    console.log('');

    await storage.close();
  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

main();
