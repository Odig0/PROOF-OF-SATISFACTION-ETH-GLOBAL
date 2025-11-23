#!/usr/bin/env node

/**
 * CLI Principal para Proof of Fun - Filecoin Integration
 */

import { FilecoinStorageService } from './FilecoinStorage.js';
import * as readline from 'readline';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query: string): Promise<string> {
  return new Promise(resolve => rl.question(query, resolve));
}

async function showMenu() {
  console.log('\n' + '='.repeat(60));
  console.log('🌟 PROOF OF FUN - FILECOIN ONCHAIN CLOUD');
  console.log('='.repeat(60));
  console.log('\n1. 📅 Almacenar Evento');
  console.log('2. 🎯 Almacenar Resultados Proof of Fun');
  console.log('3. 👕 Almacenar Catálogo Merchandise');
  console.log('4. 📥 Descargar Datos (por CID)');
  console.log('5. 💰 Ver Info de Storage');
  console.log('6. 🔄 Workflow Completo');
  console.log('7. 🚪 Salir\n');

  const choice = await question('Elige una opción (1-7): ');
  return choice.trim();
}

async function uploadEvent(storage: FilecoinStorageService) {
  console.log('\n📅 Almacenar Evento en Filecoin\n');

  const eventData = {
    id: 1,
    name: await question('Nombre del evento: '),
    description: await question('Descripción: '),
    location: await question('Ubicación: '),
    start_date: await question('Fecha inicio (YYYY-MM-DD): '),
    end_date: await question('Fecha fin (YYYY-MM-DD): '),
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
  console.log(`\n✅ Evento almacenado!`);
  console.log(`   PieceCID: ${result.pieceCid}`);
  console.log(`   Tamaño: ${result.size} bytes\n`);
}

async function downloadData(storage: FilecoinStorageService) {
  console.log('\n📥 Descargar Datos de Filecoin\n');

  const cid = await question('Ingresa el PieceCID: ');

  console.log('\n⏳ Descargando...');
  const data = await storage.download(cid);

  console.log('\n✅ Datos descargados:\n');
  console.log(JSON.stringify(data, null, 2));
  console.log('');
}

async function showStorageInfo(storage: FilecoinStorageService) {
  console.log('\n💾 Información de Storage Providers\n');
  await storage.getStorageInfo();
}

async function fullWorkflow(storage: FilecoinStorageService) {
  console.log('\n🔄 Ejecutando Workflow Completo...\n');

  // Usa datos de ejemplo
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

  console.log('📅 Almacenando evento...');
  const eventResult = await storage.storeEventMetadata(eventData);
  console.log(`   ✅ PieceCID: ${eventResult.pieceCid}\n`);

  const results = {
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
    },
    overall_rating: 4.5,
    verified_on_chain: true,
  };

  console.log('🎯 Almacenando resultados...');
  const proofResult = await storage.storeProofOfFunResults(1, results);
  console.log(`   ✅ PieceCID: ${proofResult.pieceCid}\n`);

  const merchItems = [
    {
      id: 1,
      name: 'ETH T-Shirt',
      description: 'Limited edition',
      token_price: 150,
      stock: 100,
      sizes: ['S', 'M', 'L', 'XL'],
      category: 'clothing',
    },
  ];

  console.log('👕 Almacenando merchandise...');
  const merchResult = await storage.storeMerchCatalog(merchItems);
  console.log(`   ✅ PieceCID: ${merchResult.pieceCid}\n`);

  console.log('🎉 Workflow completado exitosamente!\n');
}

async function main() {
  const storage = new FilecoinStorageService();

  try {
    console.log('\n⏳ Inicializando Synapse SDK...');
    await storage.initialize();
    console.log('✅ Conectado a Filecoin Calibration Testnet\n');

    let running = true;

    while (running) {
      const choice = await showMenu();

      try {
        switch (choice) {
          case '1':
            await uploadEvent(storage);
            break;
          case '2':
            console.log('\n🎯 Función no implementada en CLI');
            console.log('   Usa: npm run example:full\n');
            break;
          case '3':
            console.log('\n👕 Función no implementada en CLI');
            console.log('   Usa: npm run example:full\n');
            break;
          case '4':
            await downloadData(storage);
            break;
          case '5':
            await showStorageInfo(storage);
            break;
          case '6':
            await fullWorkflow(storage);
            break;
          case '7':
            running = false;
            console.log('\n👋 ¡Hasta luego!\n');
            break;
          default:
            console.log('\n❌ Opción inválida\n');
        }
      } catch (error: any) {
        console.error(`\n❌ Error: ${error.message}\n`);
      }
    }

    await storage.close();
    rl.close();
  } catch (error: any) {
    console.error(`\n❌ Error fatal: ${error.message}\n`);
    rl.close();
    process.exit(1);
  }
}

main();
