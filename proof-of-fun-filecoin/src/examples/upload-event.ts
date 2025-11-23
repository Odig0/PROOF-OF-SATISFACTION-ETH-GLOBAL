/**
 * Ejemplo simple: Almacenar metadata de un evento en Filecoin
 */

import { FilecoinStorageService } from '../FilecoinStorage.js';

async function main() {
  const storage = new FilecoinStorageService();

  try {
    await storage.initialize();

    const eventData = {
      id: 1,
      name: 'ETH Global Buenos Aires 2025',
      description: 'Hackathon internacional de Ethereum',
      location: 'Buenos Aires, Argentina',
      start_date: '2025-11-20',
      end_date: '2025-11-23',
      categories: [
        'Ambience',
        'Organization',
        'Content',
        'Technology',
        'Entertainment',
        'Accessibility',
      ],
      contract_address: '0x970fad202ADD7A19a3c377E0eCB4bbbDba9AAE49',
    };

    const result = await storage.storeEventMetadata(eventData);
    
    console.log('\n✅ Evento almacenado en Filecoin!');
    console.log(`   PieceCID: ${result.pieceCid}`);
    console.log(`   Tamaño: ${result.size} bytes\n`);

    await storage.close();
  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

main();
