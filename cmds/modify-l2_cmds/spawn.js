const ob = require('urbit-ob')
const _ = require('lodash')
const {files, validate, eth, findPoints, rollerApi} = require('../../utils')

exports.command = 'spawn'
exports.desc = 'Spawn one or more points on L2, where the points are patp or p. Can also provide the points to spawn via files. See options.'

exports.builder = function(yargs) {
  yargs.demandOption('address');
  yargs.demandOption('signing-address');
}

exports.handler = async function (argv)
{
  const workDir = files.ensureWorkDir(argv.workDir);
  const privateKey = await eth.getPrivateKey(argv);

  const rollerClient = rollerApi.createClient(argv);

  const wallets = argv.useWalletFiles ? findPoints.getWallets(workDir) : null;
  const points = findPoints.getPoints(argv, workDir, wallets);

  const signingAddress = validate.address(argv.signingAddress, true);
  //for spawning points, we do not allow it to be spawned directly to the ownership address of the master ticket, even if useWalletFiles is set.
  // .. at least not yet
  const targetAddress = validate.address(argv.address, true);

  console.log(`Will spawn ${points.length} points`);
  for (const p of points) 
  {
    const patp = ob.patp(p);
    console.log(`Trying to spawn ${patp} (${p}).`);

    const parentPoint = ob.sein(patp);
    // console.log("parent p: "+parentPoint);
    // console.log("p to spawn: "+p);
    // console.log("targetAddress: "+targetAddress);
    // console.log("signingAddress: "+signingAddress);
    // console.log("privateKey: "+privateKey);
    var transactioHash = await rollerApi.spawn(rollerClient, parentPoint, patp, targetAddress, signingAddress, privateKey);
    console.log("hash: "+transactioHash);
  } //end for each point
  
  process.exit(0);
};






