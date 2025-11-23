/**
 * Script para verificar balances de tFIL y USDFC antes de usar Synapse SDK
 */

import { Synapse, RPC_URLS, TOKENS } from '@filoz/synapse-sdk';
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

async function checkBalances() {
  console.log('\n' + '='.repeat(60));
  console.log('🔍 VERIFICACIÓN DE BALANCES - FILECOIN CALIBRATION');
  console.log('='.repeat(60) + '\n');

  try {
    // Verificar que existe PRIVATE_KEY
    if (!process.env.PRIVATE_KEY) {
      console.error('❌ Error: PRIVATE_KEY no encontrada en .env');
      console.log('\n📝 Pasos para configurar:');
      console.log('   1. Copia .env.example a .env');
      console.log('   2. Abre MetaMask > Settings > Security & Privacy');
      console.log('   3. Click "Show private key" y cópiala');
      console.log('   4. Pega tu private key en .env (sin 0x)\n');
      process.exit(1);
    }

    const rpcUrl = process.env.RPC_URL || RPC_URLS.calibration.http;
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    // Crear wallet para obtener dirección
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    console.log('🔑 Wallet Address:', wallet.address);
    console.log('🌐 Network: Filecoin Calibration Testnet\n');

    // 1. Verificar balance de tFIL (nativo)
    console.log('💰 Verificando tFIL (para gas)...');
    const filBalance = await provider.getBalance(wallet.address);
    const filBalanceFormatted = ethers.formatEther(filBalance);
    
    console.log(`   Balance: ${filBalanceFormatted} tFIL`);
    
    if (parseFloat(filBalanceFormatted) === 0) {
      console.log('   ⚠️  No tienes tFIL!');
      console.log('   👉 Visita: https://faucet.calibnet.chainsafe-fil.io/');
      console.log('   👉 Pega tu address:', wallet.address);
    } else if (parseFloat(filBalanceFormatted) < 1) {
      console.log('   ⚠️  Balance bajo de tFIL');
      console.log('   👉 Recomendado: solicitar más del faucet');
    } else {
      console.log('   ✅ Suficiente tFIL para gas fees');
    }

    // 2. Verificar balance de USDFC usando Synapse SDK
    console.log('\n💵 Verificando USDFC (para storage)...');
    console.log('   Inicializando Synapse SDK...');
    
    const synapse = await Synapse.create({
      privateKey: process.env.PRIVATE_KEY,
      rpcURL: rpcUrl,
    });

    const usdfcBalance = await synapse.payments.walletBalance(TOKENS.USDFC);
    const usdfcBalanceFormatted = ethers.formatUnits(usdfcBalance, 18);
    
    console.log(`   Balance: ${usdfcBalanceFormatted} USDFC`);
    
    if (parseFloat(usdfcBalanceFormatted) === 0) {
      console.log('   ⚠️  No tienes USDFC!');
      console.log('   👉 Visita: https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc');
      console.log('   👉 Pega tu address:', wallet.address);
    } else if (parseFloat(usdfcBalanceFormatted) < 0.5) {
      console.log('   ⚠️  Balance bajo de USDFC');
      console.log('   👉 Recomendado: solicitar más del faucet (mínimo 0.5 USDFC)');
    } else {
      console.log('   ✅ Suficiente USDFC para storage payments');
    }

    // 3. Verificar proveedores de storage
    console.log('\n📊 Verificando proveedores...');
    const storageInfo = await synapse.storage.getStorageInfo();
    const activeProviders = storageInfo.providers.filter(p => p.active);
    console.log(`   Proveedores activos: ${activeProviders.length}/${storageInfo.providers.length}`);
    console.log('   ✅ Red de storage lista');

    // 4. Verificar conectividad
    console.log('\n🌐 Verificando red...');
    const network = await provider.getNetwork();
    console.log(`   Chain ID: ${network.chainId}`);
    console.log(`   Latest Block: ${await provider.getBlockNumber()}`);
    console.log('   ✅ Conectado a Filecoin Calibration Testnet');

    // 5. Resumen y recomendaciones
    console.log('\n' + '='.repeat(60));
    console.log('📊 RESUMEN');
    console.log('='.repeat(60));
    console.log(`✅ tFIL: ${filBalanceFormatted}`);
    console.log(`${parseFloat(usdfcBalanceFormatted) > 0 ? '✅' : '❌'} USDFC: ${usdfcBalanceFormatted}`);
    console.log(`✅ Proveedores: ${activeProviders.length} activos`);
    console.log('='.repeat(60));

    const hasEnoughFil = parseFloat(filBalanceFormatted) >= 0.1;
    const hasEnoughUsdfc = parseFloat(usdfcBalanceFormatted) >= 0.5;

    if (hasEnoughFil && hasEnoughUsdfc) {
      console.log('\n🎉 ¡Todo listo! Ejecuta el workflow:\n');
      console.log('   npm run example:full\n');
    } else {
      console.log('\n⏰ Esperando tokens...');
      if (!hasEnoughUsdfc) {
        console.log('   ⏳ USDFC pendiente (necesitas mínimo 0.5 USDFC)');
        console.log('      https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc');
      }
      console.log('   💡 Ejecuta este script de nuevo para verificar\n');
    }

    console.log('🔗 Explorer: https://calibration.filscan.io/address/' + wallet.address);
    console.log('');

  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    
    if (error.message.includes('invalid private key')) {
      console.log('\n📝 Tu PRIVATE_KEY parece inválida');
      console.log('   Verifica que:');
      console.log('   1. No tenga el prefijo "0x"');
      console.log('   2. Sea de 64 caracteres hexadecimales');
      console.log('   3. Esté en .env (no en .env.example)\n');
    }
    
    process.exit(1);
  }
}

checkBalances();
