// Envoie une UserOperation ERC-4337 depuis WalletAA (Sepolia).
// Usage : node send-userop.mjs ALICE_KEY
//   (optionnel) node send-userop.mjs OLD_KEY --force  => envoie meme si la cle n'est pas le proprietaire
import { createPublicClient, http, parseEther, encodeFunctionData } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import {
    createBundlerClient,
    toSmartAccount,
    getUserOperationHash,
    entryPoint09Abi,
    entryPoint09Address,
} from 'viem/account-abstraction'

process.loadEnvFile('../.env') // lit le .env du projet (lancer depuis scripts-aa)

const keyName = process.argv[2]
const force = process.argv[3] === '--force'
if (!keyName || !process.env[keyName]) {
    console.error('Usage : node send-userop.mjs NOM_DE_LA_CLE   (ex : ALICE_KEY)')
    process.exit(1)
}

const signer = privateKeyToAccount(process.env[keyName])
const WALLET_AA = process.env.WALLET_AA
const DEST = process.env.G3_ADDR
const AMOUNT = parseEther('0.001')
const BUNDLER_URL = process.env.BUNDLER_URL ?? 'https://public.pimlico.io/v2/11155111/rpc'

const client = createPublicClient({ chain: sepolia, transport: http(process.env.RPC) })

const executeAbi = [{
    type: 'function', name: 'execute', stateMutability: 'nonpayable',
    inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }],
    outputs: [],
}]
const ownerAbi = [{
    type: 'function', name: 'owner', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }],
}]

// Fausse signature de bonne taille, uniquement pour estimer le gas
const STUB = '0x' + '11'.repeat(32) + '22'.repeat(32) + '1c'

try {
    const onchainOwner = await client.readContract({ address: WALLET_AA, abi: ownerAbi, functionName: 'owner' })
    console.log('Proprietaire on-chain :', onchainOwner)
    console.log('Cle qui signe         :', signer.address)
    if (!force && onchainOwner.toLowerCase() !== signer.address.toLowerCase()) {
        console.error("Cette cle n'est pas le proprietaire actuel : arret (ajoute --force pour tenter quand meme).")
        process.exit(1)
    }

    const account = await toSmartAccount({
        client,
        entryPoint: { abi: entryPoint09Abi, address: entryPoint09Address, version: '0.9' },
        async getAddress() { return WALLET_AA },
        async getFactoryArgs() { return {} }, // compte deja deploye : pas de factory
        async encodeCalls(calls) {
            const [call] = calls // un seul appel par operation, pour rester simple
            return encodeFunctionData({
                abi: executeAbi, functionName: 'execute',
                args: [call.to, call.value ?? 0n, call.data ?? '0x'],
            })
        },
        async getStubSignature() { return STUB },
        async sign({ hash }) { return signer.sign({ hash }) },
        async signMessage({ message }) { return signer.signMessage({ message }) },
        async signTypedData(typedData) { return signer.signTypedData(typedData) },
        async signUserOperation(parameters) {
            const { chainId = client.chain.id, ...userOperation } = parameters
            const hash = getUserOperationHash({
                chainId,
                entryPointAddress: entryPoint09Address,
                entryPointVersion: '0.9',
                userOperation: { ...userOperation, sender: WALLET_AA },
            })
            return signer.sign({ hash }) // signature brute du hash, ce que verifie SignerECDSA
        },
    })

    const bundler = createBundlerClient({
        account,
        client,
        transport: http(BUNDLER_URL),
        userOperation: {
            // frais un peu genereux pour que le bundler accepte l'operation
            estimateFeesPerGas: async () => {
                const f = await client.estimateFeesPerGas()
                const tip = f.maxPriorityFeePerGas * 2n > 1_000_000_000n ? f.maxPriorityFeePerGas * 2n : 1_000_000_000n
                const max = f.maxFeePerGas * 2n > tip ? f.maxFeePerGas * 2n : tip
                return { maxFeePerGas: max, maxPriorityFeePerGas: tip }
            },
        },
    })

    console.log('Envoi de la UserOperation au bundler...')
    const userOpHash = await bundler.sendUserOperation({ calls: [{ to: DEST, value: AMOUNT }] })
    console.log('userOpHash  :', userOpHash)

    const receipt = await bundler.waitForUserOperationReceipt({ hash: userOpHash })
    console.log('Succes      :', receipt.success)
    console.log('Transaction :', receipt.receipt.transactionHash)
    console.log('Etherscan   : https://sepolia.etherscan.io/tx/' + receipt.receipt.transactionHash)
} catch (e) {
    console.error('ERREUR :', e.shortMessage ?? e.message)
    if (e.details) console.error('Details :', e.details)
    process.exit(1)
}