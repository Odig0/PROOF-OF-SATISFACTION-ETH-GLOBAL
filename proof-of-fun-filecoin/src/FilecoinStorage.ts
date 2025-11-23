/**
 * Filecoin Storage Service usando Synapse SDK
 * Almacena metadata de eventos, resultados de Proof of Fun, y merchandise
 */

import { Synapse, RPC_URLS, TOKENS, TIME_CONSTANTS } from '@filoz/synapse-sdk';
import { ethers } from 'ethers';
import 'dotenv/config';

export interface EventMetadata {
  id: number;
  name: string;
  description: string;
  location: string;
  start_date: string;
  end_date: string;
  categories: string[];
  contract_address: string;
}

export interface ProofOfFunResults {
  event_name: string;
  total_votes: number;
  total_attendees: number;
  participation_rate: number;
  category_ratings: Record<string, {
    average: number;
    total_votes: number;
    distribution: Record<string, number>;
  }>;
  overall_rating: number;
  verified_on_chain: boolean;
}

export interface MerchItem {
  id: number;
  name: string;
  description: string;
  token_price: number;
  stock: number;
  sizes?: string[];
  category: string;
}

export class FilecoinStorageService {
  private synapse: Synapse | null = null;
  private isInitialized = false;

  constructor(
    private privateKey: string = process.env.PRIVATE_KEY || '',
    private rpcUrl: string = process.env.RPC_URL || RPC_URLS.calibration.http
  ) {
    if (!this.privateKey) {
      throw new Error('PRIVATE_KEY no configurada en .env');
    }
  }

  /**
   * Inicializa el Synapse SDK
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      console.log('⚠️  Synapse ya está inicializado');
      return;
    }

    console.log('🚀 Inicializando Synapse SDK...');
    
    this.synapse = await Synapse.create({
      privateKey: this.privateKey,
      rpcURL: this.rpcUrl,
    });

    this.isInitialized = true;
    console.log('✅ Synapse SDK inicializado correctamente');
  }

  /**
   * Configura el pago depositando USDFC
   */
  async setupPayment(amountInUSDFC: string = '2.5'): Promise<void> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n💰 Configurando pagos (${amountInUSDFC} USDFC)...`);

    // Verificar balance
    const walletBalance = await this.synapse.payments.walletBalance(TOKENS.USDFC);
    const formattedBalance = ethers.formatUnits(walletBalance, 18);
    console.log(`   Balance actual: ${formattedBalance} USDFC`);

    const depositAmount = ethers.parseUnits(amountInUSDFC, 18);

    if (walletBalance < depositAmount) {
      throw new Error(
        `Balance insuficiente. Necesitas ${amountInUSDFC} USDFC.\n` +
        `Obtén tokens de prueba en: https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc`
      );
    }

    console.log('   Depositando y aprobando Warm Storage...');
    
    const tx = await this.synapse.payments.depositWithPermitAndApproveOperator(
      depositAmount,
      this.synapse.getWarmStorageAddress(),
      ethers.MaxUint256,
      ethers.MaxUint256,
      TIME_CONSTANTS.EPOCHS_PER_MONTH,
    );

    await tx.wait();
    console.log('✅ Pago configurado exitosamente');
  }

  /**
   * Sube metadata de evento a Filecoin
   */
  async storeEventMetadata(eventData: EventMetadata): Promise<{ pieceCid: string; size: number }> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n📅 Almacenando evento: ${eventData.name}`);

    const metadata = {
      type: 'event_metadata',
      timestamp: new Date().toISOString(),
      data: eventData,
    };

    const jsonString = JSON.stringify(metadata, null, 2);
    const data = new TextEncoder().encode(jsonString);

    console.log(`   Tamaño: ${data.length} bytes`);

    const { pieceCid, size } = await this.synapse.storage.upload(data);

    console.log(`✅ Evento almacenado en Filecoin`);
    console.log(`   PieceCID: ${pieceCid}`);
    console.log(`   URL: https://ipfs.io/ipfs/${pieceCid}`);

    return { pieceCid, size };
  }

  /**
   * Sube resultados del Proof of Fun a Filecoin
   */
  async storeProofOfFunResults(
    eventId: number,
    results: ProofOfFunResults
  ): Promise<{ pieceCid: string; size: number }> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n🎯 Almacenando Proof of Fun (Evento ${eventId})...`);

    const proofData = {
      type: 'proof_of_fun_results',
      event_id: eventId,
      timestamp: new Date().toISOString(),
      results,
      blockchain_verified: true,
      network: 'Base Sepolia',
      contract: process.env.PROOF_OF_FUN_ADDRESS,
    };

    const jsonString = JSON.stringify(proofData, null, 2);
    const data = new TextEncoder().encode(jsonString);

    const { pieceCid, size } = await this.synapse.storage.upload(data);

    console.log(`✅ Resultados almacenados en Filecoin`);
    console.log(`   PieceCID: ${pieceCid}`);
    console.log(`   Rating promedio: ${results.overall_rating}`);

    return { pieceCid, size };
  }

  /**
   * Sube catálogo de merchandise a Filecoin
   */
  async storeMerchCatalog(items: MerchItem[]): Promise<{ pieceCid: string; size: number }> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n👕 Almacenando catálogo de merchandise (${items.length} items)...`);

    const catalog = {
      type: 'merch_catalog',
      timestamp: new Date().toISOString(),
      total_items: items.length,
      items,
    };

    const jsonString = JSON.stringify(catalog, null, 2);
    const data = new TextEncoder().encode(jsonString);

    const { pieceCid, size } = await this.synapse.storage.upload(data);

    console.log(`✅ Catálogo almacenado en Filecoin`);
    console.log(`   PieceCID: ${pieceCid}`);
    console.log(`   Items: ${items.length}`);

    return { pieceCid, size };
  }

  /**
   * Descarga datos desde Filecoin usando el PieceCID
   */
  async download(pieceCid: string): Promise<any> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n⬇️  Descargando desde Filecoin...`);
    console.log(`   PieceCID: ${pieceCid}`);

    const bytes = await this.synapse.storage.download(pieceCid);
    const jsonString = new TextDecoder().decode(bytes);
    const data = JSON.parse(jsonString);

    console.log(`✅ Descarga exitosa`);

    return data;
  }

  /**
   * Obtiene información de almacenamiento y proveedores
   */
  async getStorageInfo(): Promise<void> {
    if (!this.synapse) throw new Error('Synapse no inicializado');

    console.log(`\n📊 Información de almacenamiento...`);

    const storageInfo = await this.synapse.storage.getStorageInfo();
    const providers = storageInfo.providers;

    console.log(`\n   Proveedores disponibles: ${providers.length}\n`);

    providers.forEach((provider) => {
      console.log(`   ID: ${provider.id}`);
      console.log(`   Nombre: ${provider.name}`);
      console.log(`   Activo: ${provider.active}`);
      console.log(`   Dirección: ${provider.serviceProvider}`);
      console.log('   ---');
    });
  }

  /**
   * Cierra la conexión
   */
  async close(): Promise<void> {
    this.isInitialized = false;
    this.synapse = null;
    console.log('\n👋 Conexión cerrada');
  }
}
