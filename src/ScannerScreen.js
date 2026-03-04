import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';

export default function ScannerScreen({ navigation }) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);

  useEffect(() => {
    if (!permission || !permission.granted) {
      requestPermission();
    }
  }, []);

  if (!permission) {
    return <View style={styles.center}><ActivityIndicator size="large" /></View>;
  }

  if (!permission.granted) {
    return (
      <View style={styles.center}>
        <Text>Please enable camera access</Text>
      </View>
    );
  }

  const handleBarcodeScanned = (data) => {
    if (scanned) return;
    setScanned(true);

    const code = data?.data;
    navigation.navigate('Results', { barcode: code });
  };

  return (
    <View style={{ flex:1 }}>
      <CameraView
        style={{ flex:1 }}
        barcodeScannerSettings={{
          barcodeTypes: ["ean13", "ean8", "upc_a", "upc_e", "code128", "qr"]
        }}
        onBarcodeScanned={handleBarcodeScanned}
      />
      <View style={styles.scanBox}/>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex:1, justifyContent:'center', alignItems:'center' },
  scanBox: {
    position:'absolute',
    top:'40%',
    left:'15%',
    width:'70%',
    height:200,
    borderWidth:2,
    borderColor:'white',
    borderRadius:10,
  }
});
