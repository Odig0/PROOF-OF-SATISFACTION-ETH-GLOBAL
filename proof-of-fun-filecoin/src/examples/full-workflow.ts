/**
 * Ejemplo completo: Almacenar evento, resultados y merchandise en Filecoin
 */

import { FilecoinStorageService } from '../FilecoinStorage.js';

async function main() {
  console.log('\n' + '🌟'.repeat(30));
  console.log('   PROOF OF FUN - FILECOIN STORAGE');
  console.log('   Powered by Synapse SDK');
  console.log('🌟'.repeat(30));

  const storage = new FilecoinStorageService();

  try {
    // 1. Inicializar Synapse SDK
    await storage.initialize();

    // 2. Configurar pagos (solo la primera vez o si necesitas más fondos)
    // Descomenta esta línea la primera vez para depositar USDFC
    await storage.setupPayment('2.5'); // 2.5 USDFC

    // 3. Ver información de proveedores
    await storage.getStorageInfo();

    // 4. Almacenar metadata de evento
    console.log('\n' + '='.repeat(60));
    console.log('PASO 1: Almacenar Evento');
    console.log('='.repeat(60));

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

    const eventResult = await storage.storeEventMetadata(eventData);

    // 5. Almacenar resultados del Proof of Fun
    console.log('\n' + '='.repeat(60));
    console.log('PASO 2: Almacenar Resultados Proof of Fun');
    console.log('='.repeat(60));

    const proofOfFunResults = {
      event_name: 'ETH Global Buenos Aires 2025',
      total_votes: 350,
      total_attendees: 450,
      participation_rate: 77.8,
      category_ratings: {
        Ambience: {
          average: 4.5,
          total_votes: 350,
          distribution: { '1': 5, '2': 15, '3': 40, '4': 120, '5': 170 },
        },
        Organization: {
          average: 4.7,
          total_votes: 350,
          distribution: { '1': 3, '2': 10, '3': 30, '4': 107, '5': 200 },
        },
        Content: {
          average: 4.3,
          total_votes: 350,
          distribution: { '1': 8, '2': 20, '3': 50, '4': 140, '5': 132 },
        },
        Technology: {
          average: 4.6,
          total_votes: 350,
          distribution: { '1': 4, '2': 12, '3': 35, '4': 110, '5': 189 },
        },
        Entertainment: {
          average: 4.4,
          total_votes: 350,
          distribution: { '1': 6, '2': 18, '3': 45, '4': 125, '5': 156 },
        },
        Accessibility: {
          average: 4.2,
          total_votes: 350,
          distribution: { '1': 10, '2': 22, '3': 55, '4': 135, '5': 128 },
        },
      },
      overall_rating: 4.5,
      verified_on_chain: true,
    };

    const proofResult = await storage.storeProofOfFunResults(1, proofOfFunResults);

    // 6. Almacenar catálogo de merchandise
    console.log('\n' + '='.repeat(60));
    console.log('PASO 3: Almacenar Catálogo de Merchandise');
    console.log('='.repeat(60));

    const merchItems = [
      {
        id: 1,
        name: 'ETH Global T-Shirt',
        description: 'Limited edition hackathon t-shirt',
        token_price: 150,
        stock: 100,
        sizes: ['S', 'M', 'L', 'XL'],
        category: 'clothing',
      },
      {
        id: 2,
        name: 'ETH Cap',
        description: 'Baseball cap with ETH logo',
        token_price: 100,
        stock: 50,
        category: 'accessories',
      },
      {
        id: 3,
        name: 'Sticker Pack',
        description: '5 exclusive stickers',
        token_price: 50,
        stock: 200,
        category: 'accessories',
      },
      {
        id: 4,
        name: 'Laptop Sleeve',
        description: 'Protective laptop sleeve with ETH branding',
        token_price: 200,
        stock: 30,
        category: 'tech',
      },
    ];

    const merchResult = await storage.storeMerchCatalog(merchItems);

    // 7. Resumen final
    console.log('\n' + '='.repeat(60));
    console.log('✨ RESUMEN DE ALMACENAMIENTO');
    console.log('='.repeat(60));
    console.log(`\n📅 Evento:`);
    console.log(`   PieceCID: ${eventResult.pieceCid}`);
    console.log(`   Tamaño: ${eventResult.size} bytes`);

    console.log(`\n🎯 Proof of Fun:`);
    console.log(`   PieceCID: ${proofResult.pieceCid}`);
    console.log(`   Tamaño: ${proofResult.size} bytes`);

    console.log(`\n👕 Merchandise:`);
    console.log(`   PieceCID: ${merchResult.pieceCid}`);
    console.log(`   Tamaño: ${merchResult.size} bytes`);

    console.log(`\n💾 Total almacenado: ${
      eventResult.size + proofResult.size + merchResult.size
    } bytes`);

    console.log('\n🔗 Todos los datos están ahora en Filecoin Onchain Cloud!');
    console.log('🌍 Accesibles de forma descentralizada vía IPFS/Filecoin\n');

    // 8. Ejemplo de descarga (opcional)
    console.log('\n' + '='.repeat(60));
    console.log('BONUS: Verificar Descarga');
    console.log('='.repeat(60));

    const downloaded = await storage.download(proofResult.pieceCid);
    console.log(`\n   Tipo de dato descargado: ${downloaded.type}`);
    console.log(`   Rating promedio verificado: ${downloaded.results.overall_rating}`);

    await storage.close();

    console.log('\n' + '='.repeat(60));
    console.log('🎉 WORKFLOW COMPLETADO EXITOSAMENTE');
    console.log('='.repeat(60) + '\n');

  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    if (error.cause) {
      console.error('   Causa:', error.cause);
    }
    process.exit(1);
  }
}

main().catch(console.error);
