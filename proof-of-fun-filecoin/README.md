# Proof of Fun - Filecoin Integration

Integración con Filecoin Onchain Cloud usando Synapse SDK para almacenar datos de eventos, resultados de votaciones y catálogos de merchandise de forma descentralizada.

## 🎯 Bounty: Filecoin Onchain Cloud ($10,000)

Esta integración cumple con los requisitos del bounty:

- ✅ **Usa Synapse SDK**: Implementación completa con `@filoz/synapse-sdk`
- ✅ **Desplegado en Calibration Testnet**: Configurado para la testnet de Filecoin
- ✅ **Demo funcional**: Ejemplos completos con CLI y workflow
- ✅ **Open Source**: Código disponible en GitHub

## 📦 Características

- 📅 **Almacenamiento de Eventos**: Guarda metadata de eventos en Filecoin
- 🎯 **Resultados Proof of Fun**: Almacena resultados de votaciones verificables
- 👕 **Catálogo de Merchandise**: Guarda inventario y precios en IPFS/Filecoin
- 🔐 **Verificable On-Chain**: Todos los datos vinculados a contratos en Base Sepolia
- 🌍 **Acceso Descentralizado**: Datos accesibles vía IPFS y Filecoin

## 🚀 Configuración Rápida

### 1. Instalar Dependencias

```bash
cd proof-of-fun-filecoin
npm install
```

### 2. Configurar Variables de Entorno

```bash
cp .env.example .env
```

Edita `.env` y agrega tu private key de MetaMask:

```env
PRIVATE_KEY=tu_private_key_aqui
RPC_URL=https://api.calibration.node.glif.io/rpc/v1
```

### 3. Obtener Tokens de Prueba

Necesitas 2 tipos de tokens en Filecoin Calibration Testnet:

#### a) tFIL (para gas):
- Visita: https://faucet.calibnet.chainsafe-fil.io/
- Pega tu dirección de wallet
- Recibe ~10 tFIL

#### b) USDFC (para pagar storage):
- Visita: https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc
- Pega tu dirección de wallet
- Recibe ~10 USDFC

**⏰ Tiempo de espera**: Los tokens pueden tardar 5-10 minutos en llegar.

### 4. Verificar Balance

```bash
npm run dev src/examples/check-balance.ts
```

## 💡 Ejemplos de Uso

### Workflow Completo (Recomendado)

```bash
npm run example:full
```

Este comando ejecuta el workflow completo:
1. ✅ Inicializa Synapse SDK
2. 💰 Configura pagos (deposita USDFC)
3. 📅 Almacena evento en Filecoin
4. 🎯 Almacena resultados Proof of Fun
5. 👕 Almacena catálogo de merchandise
6. 📥 Descarga y verifica datos

### Solo Almacenar Evento

```bash
npm run example:upload
```

### Descargar Datos

```bash
npm run example:download <PieceCID>
```

Ejemplo:
```bash
npm run example:download baga6ea4seaqao7s73y24ciu75q76k2...
```

## 📊 Estructura del Proyecto

```
proof-of-fun-filecoin/
├── src/
│   ├── FilecoinStorage.ts      # Servicio principal con Synapse SDK
│   └── examples/
│       ├── full-workflow.ts     # Workflow completo (recomendado)
│       ├── upload-event.ts      # Solo almacenar evento
│       └── download-data.ts     # Descargar datos por CID
├── package.json
├── tsconfig.json
└── .env.example
```

## 🔧 API Reference

### `FilecoinStorageService`

#### `initialize()`
Inicializa el cliente Synapse SDK con tu wallet.

```typescript
await storage.initialize();
```

#### `setupPayment(amount: string)`
Deposita USDFC y aprueba Warm Storage operator.

```typescript
await storage.setupPayment('2.5'); // 2.5 USDFC = 1TiB por 30 días
```

#### `storeEventMetadata(event: EventMetadata)`
Almacena metadata de un evento en Filecoin.

```typescript
const result = await storage.storeEventMetadata({
  id: 1,
  name: 'ETH Global Buenos Aires 2025',
  description: 'Hackathon internacional',
  location: 'Buenos Aires, Argentina',
  start_date: '2025-11-20',
  end_date: '2025-11-23',
  categories: ['Ambience', 'Organization', 'Content', ...],
  contract_address: '0x970fad202ADD7A19a3c377E0eCB4bbbDba9AAE49'
});

console.log(result.pieceCid); // baga6ea4seaq...
```

#### `storeProofOfFunResults(eventId, results)`
Almacena resultados de votaciones.

```typescript
const result = await storage.storeProofOfFunResults(1, {
  event_name: 'ETH Global Buenos Aires 2025',
  total_votes: 350,
  category_ratings: { ... },
  overall_rating: 4.5,
  verified_on_chain: true
});
```

#### `storeMerchCatalog(items: MerchItem[])`
Almacena catálogo de merchandise.

```typescript
const result = await storage.storeMerchCatalog([
  {
    id: 1,
    name: 'ETH T-Shirt',
    token_price: 150,
    stock: 100,
    sizes: ['S', 'M', 'L', 'XL']
  }
]);
```

#### `download(pieceCid: string)`
Descarga datos desde Filecoin usando PieceCID.

```typescript
const data = await storage.download('baga6ea4seaq...');
console.log(data);
```

## 🔗 Contratos en Base Sepolia

Todos los contratos están verificados y publicados:

- **ProofOfFun**: `0x970fad202ADD7A19a3c377E0eCB4bbbDba9AAE49`
- **EventManager**: `0x45E2b22464cb62740f2B3319d6140888e1cDb9A0`
- **AnonymousVoteToken**: `0xCE48637ef4f6A010F83786d3DC2a80B26913cE01`
- **MerchRedemption**: `0x89dBb9B19F74f5fC5e329379fA34cEFC518b980c`

Verifica en: https://sepolia.basescan.org

## 📚 Recursos

- [Synapse SDK Docs](https://docs.filecoin.cloud/)
- [Filecoin Calibration Explorer](https://calibration.filscan.io/)
- [tFIL Faucet](https://faucet.calibnet.chainsafe-fil.io/)
- [USDFC Faucet](https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc)

## 🎯 Casos de Uso

### 1. Organizador de Evento
```typescript
// Crear evento y guardar metadata en Filecoin
const result = await storage.storeEventMetadata(eventData);
// PieceCID se guarda on-chain en EventManager
```

### 2. Finalizar Evento
```typescript
// Almacenar resultados finales de votaciones
const result = await storage.storeProofOfFunResults(eventId, results);
// Resultados inmutables y verificables
```

### 3. Setup Merchandise Store
```typescript
// Publicar catálogo de productos
const result = await storage.storeMerchCatalog(merchItems);
// Frontend descarga catálogo desde IPFS/Filecoin
```

## ⚠️ Troubleshooting

### "Insufficient balance"
- Verifica que tengas tFIL (gas) y USDFC (storage)
- Usa los faucets listados arriba

### "File too small (minimum 127 bytes)"
- Synapse requiere mínimo 127 bytes
- Agrega padding si es necesario (ya incluido en código)

### "Cannot find module"
- Ejecuta `npm install`
- Verifica que estés en la carpeta `proof-of-fun-filecoin/`

### Tokens no llegan
- Espera 5-10 minutos
- Verifica tu dirección en el explorer de Calibration
- Intenta con otro faucet si persiste

## 🏆 Contribuciones

Este proyecto es parte del bounty de Filecoin en ETH Global 2025. Contribuciones son bienvenidas!

## 📄 Licencia

MIT License - Ver contratos inteligentes en `../proof-of-fun-hardhat-v3/`

---

**Desarrollado para ETH Global Buenos Aires 2025** 🇦🇷
