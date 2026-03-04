import React, { useEffect, useState } from 'react';
import { View, Text, FlatList, StyleSheet, Image, ActivityIndicator } from 'react-native';
import mockPrices from './mockPrices';

export default function ResultsScreen({ route }) {
  const { barcode } = route.params;
  const [loading, setLoading] = useState(true);
  const [prices, setPrices] = useState([]);

  useEffect(() => {
    setTimeout(() => {
      setPrices(mockPrices(barcode));
      setLoading(false);
    }, 1000);
  }, [barcode]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
        <Text style={{ marginTop:10 }}>Loading prices...</Text>
      </View>
    );
  }

  return (
    <View style={{ flex:1, padding:15 }}>
      <Text style={styles.title}>Results for {barcode}</Text>

      <FlatList
        data={prices}
        keyExtractor={(item) => item.store}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Image source={{ uri: item.image }} style={styles.img} />
            <View style={{ flex:1 }}>
              <Text style={styles.store}>{item.store}</Text>
              <Text style={styles.price}>${item.price}</Text>
            </View>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex:1, justifyContent:'center', alignItems:'center' },
  title: { fontSize:18, fontWeight:'bold', marginBottom:15 },
  card: { flexDirection:'row', background:'#eee', padding:10, borderRadius:8, marginBottom:10 },
  img: { width:60, height:60, marginRight:10 },
  store: { fontSize:16 },
  price: { fontSize:18, fontWeight:'bold', marginTop:5 },
});
