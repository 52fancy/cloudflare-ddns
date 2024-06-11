package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io/ioutil"
    "net/http"
    "os"
)

const (
    cloudflareAPIURL = "https://api.cloudflare.com/client/v4"
)

type CloudflareResponse struct {
    Success bool `json:"success"`
    Errors  []struct {
        Code    int    `json:"code"`
        Message string `json:"message"`
    } `json:"errors"`
}

func main() {
    if len(os.Args) < 6 {
        fmt.Println("Usage: ./ddns CFKEY 1234567890 CFUSER user@example.com CFZONE_NAME example.com CFRECORD_NAME host.example.com CFRECORD_TYPE A|AAAA|Both")
        os.Exit(1)
    }

    CFKEY := os.Args[2]
    CFUSER := os.Args[4]
    CFZONE_NAME := os.Args[6]
    CFRECORD_NAME := os.Args[8]
    CFRECORD_TYPE := os.Args[10]

    // Get Zone ID
    zoneID, err := getZoneID(CFKEY, CFUSER, CFZONE_NAME)
    if err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    // Get WAN IP
    ipv4, ipv6 := "", ""
    if CFRECORD_TYPE == "A" || CFRECORD_TYPE == "Both" {
        // Get DNS record IP
        dnsRecordIP, err := getDNSRecordIP(CFKEY, CFUSER, zoneID, CFRECORD_NAME, "A")
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
        ipv4, err = getWANIP("ipv4")
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
        // Check if the DNS record IP matches the WAN IP
        if dnsRecordIP == ipv4 {
            fmt.Printf("DNS record %s matches the WAN IPV4. No update needed.\n", dnsRecordIP)
            ipv4 = ""
        }
    }
    if CFRECORD_TYPE == "AAAA" || CFRECORD_TYPE == "Both" {
        // Get DNS record IP
        dnsRecordIP, err := getDNSRecordIP(CFKEY, CFUSER, zoneID, CFRECORD_NAME, "AAAA")
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
        ipv6, err = getWANIP("ipv6")
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
        // Check if the DNS record IP matches the WAN IP
        if dnsRecordIP == ipv6 {
            fmt.Printf("DNS record %s matches the WAN IPV6. No update needed.\n", dnsRecordIP)
            ipv6 = ""
        }
    }

    // Update DNS record
    if ipv4 != "" {
        err = updateDNSRecord(CFKEY, CFUSER, zoneID, CFRECORD_NAME, "A", ipv4)
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
    }

    if ipv6 != "" {
        err = updateDNSRecord(CFKEY, CFUSER, zoneID, CFRECORD_NAME, "AAAA", ipv6)
        if err != nil {
            fmt.Println("Error:", err)
            os.Exit(1)
        }
    }
}

func getZoneID(CFKEY, CFUSER, CFZONE_NAME string) (string, error) {
    url := fmt.Sprintf("%s/zones?name=%s", cloudflareAPIURL, CFZONE_NAME)
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return "", err
    }
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Auth-Email", CFUSER)
    req.Header.Set("X-Auth-Key", CFKEY)

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    var data struct {
        Result []struct {
            ID string `json:"id"`
        } `json:"result"`
    }
    if err := json.Unmarshal(body, &data); err != nil {
        return "", err
    }

    if len(data.Result) == 0 {
        return "", fmt.Errorf("zone not found: %s", CFZONE_NAME)
    }

    return data.Result[0].ID, nil
}

func getWANIP(ipType string) (string, error) {
    url := ""
    if ipType == "ipv6" {
        url = "http://ipv6.icanhazip.com"
    } else {
        url = "http://ipv4.icanhazip.com"
    }

    resp, err := http.Get(url)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    return string(bytes.TrimSpace(body)), nil
}

func getDNSRecordIP(CFKEY, CFUSER, zoneID, CFRECORD_NAME, CFRECORD_TYPE string) (string, error) {
    url := fmt.Sprintf("%s/zones/%s/dns_records?type=%s&name=%s", cloudflareAPIURL, zoneID, CFRECORD_TYPE, CFRECORD_NAME)
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return "", err
    }
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Auth-Email", CFUSER)
    req.Header.Set("X-Auth-Key", CFKEY)

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    var data struct {
        Result []struct {
            Content string `json:"content"`
        } `json:"result"`
    }
    if err := json.Unmarshal(body, &data); err != nil {
        return "", err
    }

    if len(data.Result) == 0 {
        return "", fmt.Errorf("DNS record not found: %s", CFRECORD_NAME)
    }

    return data.Result[0].Content, nil
}

func updateDNSRecord(CFKEY, CFUSER, zoneID, CFRECORD_NAME, CFRECORD_TYPE, wanIP string) error {
    url := fmt.Sprintf("%s/zones/%s/dns_records?type=%s&name=%s", cloudflareAPIURL, zoneID, CFRECORD_TYPE, CFRECORD_NAME)
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return err
    }
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Auth-Email", CFUSER)
    req.Header.Set("X-Auth-Key", CFKEY)

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return err
    }

    var data struct {
        Result []struct {
            ID string `json:"id"`
        } `json:"result"`
    }
    if err := json.Unmarshal(body, &data); err != nil {
        return err
    }

    if len(data.Result) == 0 {
        return fmt.Errorf("DNS record not found: %s", CFRECORD_NAME)
    }

    dnsRecordID := data.Result[0].ID

    updateURL := fmt.Sprintf("%s/zones/%s/dns_records/%s", cloudflareAPIURL, zoneID, dnsRecordID)
    requestData := map[string]string{
        "type":    CFRECORD_TYPE,
        "name":    CFRECORD_NAME,
        "content": wanIP,
    }
    jsonData, err := json.Marshal(requestData)
    if err != nil {
        return err
    }

    req, err = http.NewRequest("PUT", updateURL, bytes.NewBuffer(jsonData))
    if err != nil {
        return err
    }
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Auth-Email", CFUSER)
    req.Header.Set("X-Auth-Key", CFKEY)

    resp, err = http.DefaultClient.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    body, err = ioutil.ReadAll(resp.Body)
    if err != nil {
        return err
    }

    var cfResp CloudflareResponse
    if err := json.Unmarshal(body, &cfResp); err != nil {
        return err
    }

    if !cfResp.Success {
        errMsg := "Unknown error"
        if len(cfResp.Errors) > 0 {
            errMsg = cfResp.Errors[0].Message
        }
        return fmt.Errorf("Cloudflare API error: %s", errMsg)
    }

    if CFRECORD_TYPE == "AAAA" {
        fmt.Println("Updated ipv6 successfully!")
    } else {
        fmt.Println("Updated ipv4 successfully!")
    }

    fmt.Println(wanIP)
    return nil
}
