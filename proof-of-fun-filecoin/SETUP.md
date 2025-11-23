# 🚀 Guía de Configuración Rápida

## Paso 1: Configurar tu Wallet

1. **Obtén tu Private Key de MetaMask:**
   - Abre MetaMask
   - Click en los 3 puntos → Settings
   - Security & Privacy → Show private key
   - Ingresa tu contraseña
   - **Copia la private key (64 caracteres)**

2. **Configura el archivo .env:**
   ```bash
   # Ya se creó .env automáticamente
   # Ahora edítalo con tu editor
   code .env
   ```

3. **Pega tu private key en .env:**
   ```env
   PRIVATE_KEY=tu_private_key_de_64_caracteres_SIN_0x
   ```

## Paso 2: Obtener Test Tokens

Ya completaste estos pasos ✅:

### tFIL (para gas fees)
- ✅ Visitaste: https://faucet.calibnet.chainsafe-fil.io/
- ✅ Ingresaste tu address
- ⏰ Espera 5-10 minutos

### USDFC (para storage payments)
- ✅ Visitaste: https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc
- ✅ Ingresaste tu address
- ⏰ Espera 5-10 minutos

## Paso 3: Verificar Balances

Ejecuta este comando para ver si tus tokens llegaron:

```bash
npm run check
```

**Deberías ver:**
```
✅ Suficiente tFIL para gas fees
✅ Suficiente USDFC para storage payments
```

## Paso 4: Ejecutar Workflow Completo

Una vez que tengas ambos tokens:

```bash
npm run example:full
```

Esto hará:
- 📅 Almacenar evento en Filecoin
- 🎯 Guardar resultados Proof of Fun
- 👕 Subir catálogo de merchandise
- 📥 Descargar y verificar datos

## ⚠️ Troubleshooting

### "PRIVATE_KEY no encontrada"
- Verifica que editaste `.env` (no `.env.example`)
- La private key debe ser de 64 caracteres
- NO incluyas el prefijo "0x"

### "Balance: 0 tFIL"
- Espera 5-10 minutos después de solicitar del faucet
- Verifica tu address en: https://calibration.filscan.io/

### "Balance: 0 USDFC"
- Los tokens USDFC pueden tardar más
- Intenta nuevamente en el faucet si pasan 15 minutos

## 🔗 Links Útiles

- **Faucet tFIL**: https://faucet.calibnet.chainsafe-fil.io/
- **Faucet USDFC**: https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc
- **Explorer**: https://calibration.filscan.io/
- **Docs Synapse**: https://docs.filecoin.cloud/

## 📊 Comandos Disponibles

```bash
npm run check           # Verificar balances de tFIL y USDFC
npm run example:upload  # Solo subir un evento
npm run example:full    # Workflow completo (recomendado)
npm run dev             # CLI interactivo
```

## ✨ ¿Todo funcionó?

Si `npm run check` muestra ✅ en ambos tokens, estás listo para:

```bash
npm run example:full
```

¡Y tendrás tus datos almacenados en Filecoin! 🎉
